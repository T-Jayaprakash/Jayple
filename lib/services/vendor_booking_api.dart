import 'package:cloud_functions/cloud_functions.dart';

class VendorBookingApi {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<Map<String, dynamic>>> getVendorBookings() async {
    try {
      // Uses the same endpoint as customers, but backend returns vendor-relevant bookings
      final HttpsCallable callable = _functions.httpsCallable('getMyBookings');
      final result = await callable.call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final List bookings = data['bookings'] ?? [];
      return bookings.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message}');
    } catch (e) {
      throw Exception('Failed to load bookings: $e');
    }
  }

  Future<Map<String, dynamic>> getVendorBookingById(String bookingId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getBookingById');
      final result = await callable.call({'bookingId': bookingId});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      throw Exception('Failed to load booking details: $e');
    }
  }

  Future<void> respondToBooking({
    required String bookingId,
    required String cityId,
    required String action, // 'accept' or 'reject'
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('vendorRespondToBooking');
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
}
