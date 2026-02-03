import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FreelancerBookingApi {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getFreelancerJobs() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getMyBookings');
      final result = await callable.call();
      
      final data = Map<String, dynamic>.from(result.data as Map);
      final List rawList = data['bookings'] ?? [];
      
      final String? currentUid = _auth.currentUser?.uid;
      if (currentUid == null) throw Exception('User not authenticated');

      // MANDATORY Client-side Filtering
      return rawList.map((e) => Map<String, dynamic>.from(e as Map)).where((booking) {
        final type = booking['type'];
        final freelancerId = booking['freelancerId'];
        final status = booking['status'];

        final bool isValidType = type == 'home';
        final bool isMyJob = freelancerId == currentUid;
        final bool isCorrectStatus = ['ASSIGNED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED'].contains(status);

        return isValidType && isMyJob && isCorrectStatus;
      }).toList();

    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message} (${e.code})');
    } catch (e) {
      throw Exception('Failed to fetch jobs: $e');
    }
  }

  Future<Map<String, dynamic>> getJobDetail(String bookingId) async {
    try {
       final HttpsCallable callable = _functions.httpsCallable('getBookingById');
       final result = await callable.call({'bookingId': bookingId});
       return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      throw Exception('Failed to fetch details: $e');
    }
  }

  Future<void> respondToBooking({
    required String bookingId,
    required String cityId,
    required String action, // "ACCEPT" | "REJECT"
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('freelancerRespondToBooking');
      await callable.call({
        'bookingId': bookingId,
        'cityId': cityId,
        'action': action,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message} (${e.code})');
    } catch (e) {
      throw Exception('Action failed: $e');
    }
  }

  Future<void> startJob({
    required String bookingId,
    required String cityId,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('completeBooking');
      await callable.call({
        'bookingId': bookingId,
        'cityId': cityId,
        'action': 'START',
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message} (${e.code})');
    } catch (e) {
      throw Exception('Failed to start job: $e');
    }
  }

  Future<void> completeJob({
    required String bookingId,
    required String cityId,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('completeBooking');
      await callable.call({
        'bookingId': bookingId,
        'cityId': cityId,
        'action': 'COMPLETE',
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message} (${e.code})');
    } catch (e) {
      throw Exception('Failed to complete job: $e');
    }
  }
}
