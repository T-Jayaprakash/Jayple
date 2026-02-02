import 'package:cloud_functions/cloud_functions.dart';

class BookingApi {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Mock Services for Browsing (Direct Firestore Read Forbidden)
  static const List<Map<String, dynamic>> mockServices = [
    {
      'id': 'svc_haircut_basic',
      'name': 'Basic Haircut',
      'category': 'haircut',
      'duration': 30, // minutes
      'price': 250,
      'description': 'A clean, professional haircut starting with a consultation.'
    },
    {
      'id': 'svc_shave_royal',
      'name': 'Royal Shave',
      'category': 'shaving',
      'duration': 20,
      'price': 150,
      'description': 'Hot towel shave with premium grooming products.'
    },
    {
      'id': 'svc_massage_head',
      'name': 'Head Massage',
      'category': 'massage',
      'duration': 15,
      'price': 200,
      'description': 'Relaxing head massage to relieve stress.'
    }
  ];

  Future<Map<String, dynamic>> createBooking({
    required String serviceId,
    required String cityId,
    required DateTime scheduledAt,
    String type = 'home',
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('createBooking');
      final result = await callable.call({
        'serviceId': serviceId,
        'cityId': cityId,
        'type': type,
        'scheduledAt': scheduledAt.millisecondsSinceEpoch,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message} (${e.code})');
    } catch (e) {
      throw Exception('Unified Error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMyBookings() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getMyBookings');
      final result = await callable.call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final List bookings = data['bookings'] ?? [];
      return bookings.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on FirebaseFunctionsException catch (e) {
       throw Exception('${e.message}');
    } catch (e) {
       throw Exception('$e');
    }
  }

  Future<Map<String, dynamic>> getBookingById(String bookingId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getBookingById');
      final result = await callable.call({'bookingId': bookingId});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      throw Exception('$e');
    }
  }

  Future<void> authorizePayment(String bookingId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('authorizePayment');
      await callable.call({'bookingId': bookingId});
    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message} (${e.code})');
    } catch (e) {
      throw Exception('Payment Failed: $e');
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('cancelBooking');
      await callable.call({'bookingId': bookingId});
    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message} (${e.code})');
    } catch (e) {
      throw Exception('Cancellation Failed: $e');
    }
  }
}
