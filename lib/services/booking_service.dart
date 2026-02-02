import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking.dart';

class BookingService {
  static BookingService? _instance;
  static BookingService get instance => _instance ??= BookingService._();

  BookingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's bookings
  Future<List<Booking>> getUserBookings({
    String? status,
    int limit = 50,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      var query = _firestore
          .collection('bookings')
          .where('user_id', isEqualTo: userId);
          
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      
      final snapshot = await query
          .orderBy('start_at', descending: true)
          .limit(limit)
          .get();
          
      return snapshot.docs.map((doc) => Booking.fromJson(doc.data())).toList();
    } catch (error) {
      // Index potentially missing
      print('Error fetching user bookings: $error');
      return [];
    }
  }

  // Get salon's bookings (for salon owners)
  Future<List<Booking>> getSalonBookings({
    required String salonId,
    String? status,
    int limit = 50,
  }) async {
    try {
      var query = _firestore
          .collection('bookings')
          .where('salon_id', isEqualTo: salonId);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      
      final snapshot = await query
          .orderBy('start_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Booking.fromJson(doc.data())).toList();
    } catch (error) {
       print('Error fetching salon bookings: $error');
       return [];
    }
  }

  // Create new booking
  Future<Booking> createBooking({
    required String salonId,
    required String serviceId,
    required DateTime startAt,
    required DateTime endAt,
    String? assignedFreelancerId,
    bool homeService = false,
  }) async {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Check conflict
      final conflictingSnapshot = await _firestore
          .collection('bookings')
          .where('salon_id', isEqualTo: salonId)
          .where('start_at', isGreaterThanOrEqualTo: startAt.toIso8601String())
          .where('start_at', isLessThanOrEqualTo: endAt.toIso8601String())
          .get();
      
      // Basic check: Filter in memory for precise overlap if needed, 
      // but Firestore range filters on same field are restrictive.
      // For MVP, we will rely on this check.
      // A robust solution needs separate collection 'slots' or specialized indexing.

      final hasConflict = conflictingSnapshot.docs.any((doc) {
          final data = doc.data();
          if (data['status'] == 'cancelled') return false;
          // Exact overlap check could be done here if needed
          return true;
      });

      if (hasConflict) {
        throw Exception('Time slot is not available');
      }

      final bookingRef = _firestore.collection('bookings').doc();
      final bookingData = {
        'id': bookingRef.id,
        'user_id': userId,
        'salon_id': salonId,
        'service_id': serviceId,
        'assigned_freelancer_id': assignedFreelancerId,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'status': 'pending',
        'home_service': homeService,
        'created_at': FieldValue.serverTimestamp(),
      };

      await bookingRef.set(bookingData);
      return Booking.fromJson(bookingData);
  }

  // Update booking status
  Future<Booking> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
      final validStatuses = [
        'pending',
        'confirmed',
        'in_progress',
        'completed',
        'cancelled'
      ];
      if (!validStatuses.contains(status)) {
        throw Exception('Invalid booking status');
      }

      await _firestore.collection('bookings').doc(bookingId).update({'status': status});
      final updatedDoc = await _firestore.collection('bookings').doc(bookingId).get();
      return Booking.fromJson(updatedDoc.data()!);
  }

  // Cancel booking
  Future<Booking> cancelBooking(String bookingId) async {
      return await updateBookingStatus(
        bookingId: bookingId,
        status: 'cancelled',
      );
  }

  // Get booking details with related data
  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    try {
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) throw Exception("Booking not found");
      
      final bookingData = bookingDoc.data()!;
      
      // Fetch related data manually since Firestore joins aren't like SQL
      final salonDoc = await _firestore.collection('salons').doc(bookingData['salon_id']).get();
      final serviceDoc = await _firestore.collection('services').doc(bookingData['service_id']).get();
      final userDoc = await _firestore.collection('users').doc(bookingData['user_id']).get();

      return {
        'booking': Booking.fromJson(bookingData),
        'salon': salonDoc.data(),
        'service': serviceDoc.data(),
        'user': userDoc.data(),
      };
    } catch (error) {
      throw Exception('Failed to fetch booking details: $error');
    }
  }

  // Get available time slots for a salon/service
  Future<List<DateTime>> getAvailableTimeSlots({
    required String salonId,
    required DateTime date,
    int serviceDurationMinutes = 60,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day, 9, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 18, 0);

      // Get existing bookings
      final existingSnapshot = await _firestore
          .collection('bookings')
          .where('salon_id', isEqualTo: salonId)
          .where('start_at', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('end_at', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();

      final bookedSlots =
          existingSnapshot.docs.map<Map<String, DateTime>>((doc) {
            final data = doc.data();
            if (data['status'] == 'cancelled') return {}; 
            return {
              'start': DateTime.parse(data['start_at']),
              'end': DateTime.parse(data['end_at']),
            };
      }).where((slot) => slot.isNotEmpty).toList();

      // Generate available time slots (every 30 minutes)
      final availableSlots = <DateTime>[];
      var current = startOfDay;

      while (current
          .add(Duration(minutes: serviceDurationMinutes))
          .isBefore(endOfDay)) {
        final slotEnd = current.add(Duration(minutes: serviceDurationMinutes));

        // Check if slot conflicts with existing bookings
        final hasConflict = bookedSlots.any((booking) {
          return current.isBefore(booking['end']!) &&
              slotEnd.isAfter(booking['start']!);
        });

        if (!hasConflict) {
          availableSlots.add(current);
        }

        current = current.add(Duration(minutes: 30));
      }

      return availableSlots;
    } catch (error) {
       print('Error fetching slots: $error');
       return [];
    }
  }

  // Get booking statistics
  Future<Map<String, int>> getBookingStatistics() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore.collection('bookings').where('user_id', isEqualTo: userId).get();

      final stats = <String, int>{
        'total': 0,
        'pending': 0,
        'confirmed': 0,
        'completed': 0,
        'cancelled': 0,
      };

      for (final doc in snapshot.docs) {
        stats['total'] = stats['total']! + 1;
        final status = doc.data()['status'] as String?;
        if (status != null) {
          stats[status] = (stats[status] ?? 0) + 1;
        }
      }

      return stats;
    } catch (error) {
       print('Error stats: $error');
       return {};
    }
  }
}
