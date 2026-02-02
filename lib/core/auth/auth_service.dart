import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_model.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser> fetchUser(String uid) async {
    // Fetch ONCE, no streams
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('User document missing or empty');
    }

    try {
      return AppUser.fromFirestore(doc.data()!, uid);
    } catch (e) {
      throw FormatException('User data invalid: $e');
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
