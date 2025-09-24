import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';

class BookingService {
  static BookingService? _instance;
  static BookingService get instance => _instance ??= BookingService._();

  BookingService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Get user's bookings
  Future<List<Booking>> getUserBookings({
    String? status,
    int limit = 50,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _client
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .order('start_at', ascending: false)
          .limit(limit);
      if (status != null) {
        query = _client
            .from('bookings')
            .select()
            .eq('user_id', userId)
            .eq('status', status)
            .order('start_at', ascending: false)
            .limit(limit);
      }

      final response = await query;
      return response.map<Booking>((json) => Booking.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Failed to fetch bookings: $error');
    }
  }

  // Get salon's bookings (for salon owners)
  Future<List<Booking>> getSalonBookings({
    required String salonId,
    String? status,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('bookings')
          .select()
          .eq('salon_id', salonId)
          .order('start_at', ascending: false)
          .limit(limit);
      if (status != null) {
        query = _client
            .from('bookings')
            .select()
            .eq('salon_id', salonId)
            .eq('status', status)
            .order('start_at', ascending: false)
            .limit(limit);
      }

      final response = await query;
      return response.map<Booking>((json) => Booking.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Failed to fetch salon bookings: $error');
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
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if slot is available
      final conflictingBookings = await _client
          .from('bookings')
          .select()
          .eq('salon_id', salonId)
          .gte('start_at', startAt.toIso8601String())
          .lte('start_at', endAt.toIso8601String())
          .neq('status', 'cancelled');

      if (conflictingBookings.isNotEmpty) {
        throw Exception('Time slot is not available');
      }

      final bookingData = {
        'user_id': userId,
        'salon_id': salonId,
        'service_id': serviceId,
        'assigned_freelancer_id': assignedFreelancerId,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'status': 'pending',
        'home_service': homeService,
      };

      final response =
          await _client.from('bookings').insert(bookingData).select().single();

      return Booking.fromJson(response);
    } catch (error) {
      throw Exception('Failed to create booking: $error');
    }
  }

  // Update booking status
  Future<Booking> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
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

      final response = await _client
          .from('bookings')
          .update({'status': status})
          .eq('id', bookingId)
          .select()
          .single();

      return Booking.fromJson(response);
    } catch (error) {
      throw Exception('Failed to update booking: $error');
    }
  }

  // Cancel booking
  Future<Booking> cancelBooking(String bookingId) async {
    try {
      return await updateBookingStatus(
        bookingId: bookingId,
        status: 'cancelled',
      );
    } catch (error) {
      throw Exception('Failed to cancel booking: $error');
    }
  }

  // Get booking details with related data
  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    try {
      final response = await _client.from('bookings').select('''
            *,
            salons(*),
            services(*),
            users(*)
          ''').eq('id', bookingId).single();

      return {
        'booking': Booking.fromJson(response),
        'salon': response['salons'],
        'service': response['services'],
        'user': response['users'],
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

      // Get existing bookings for the day
      final existingBookings = await _client
          .from('bookings')
          .select()
          .eq('salon_id', salonId)
          .gte('start_at', startOfDay.toIso8601String())
          .lte('end_at', endOfDay.toIso8601String())
          .neq('status', 'cancelled');

      final bookedSlots =
          existingBookings.map<Map<String, DateTime>>((booking) {
        return {
          'start': DateTime.parse(booking['start_at']),
          'end': DateTime.parse(booking['end_at']),
        };
      }).toList();

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
      throw Exception('Failed to fetch available slots: $error');
    }
  }

  // Get booking statistics
  Future<Map<String, int>> getBookingStatistics() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final allBookings =
          await _client.from('bookings').select('status').eq('user_id', userId);

      final stats = <String, int>{
        'total': 0,
        'pending': 0,
        'confirmed': 0,
        'completed': 0,
        'cancelled': 0,
      };

      for (final booking in allBookings) {
        stats['total'] = stats['total']! + 1;
        final status = booking['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (error) {
      throw Exception('Failed to fetch booking statistics: $error');
    }
  }
}
