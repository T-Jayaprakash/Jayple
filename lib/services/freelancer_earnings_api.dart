import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FreelancerEarningsApi {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getEarnings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final HttpsCallable callable = _functions.httpsCallable('getMyEarnings');
      final result = await callable.call();
      
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('${e.message} (${e.code})');
    } catch (e) {
      throw Exception('Failed to load earnings: $e');
    }
  }
}
