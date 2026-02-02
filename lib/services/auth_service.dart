import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart' as user_model;

class AuthService {
  static final AuthService instance = AuthService._internal();

  factory AuthService() {
    return instance;
  }

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Verify Phone Number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-resolution (mostly Android)
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  // Verify OTP and Sign In
  Future<UserCredential> signInWithOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // Check if User Profile exists and get Role
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role') as String?;
      }
      return null; // User exists in Auth but not in Firestore (needs role selection)
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  // Create User Profile
  Future<void> createUserProfile(String uid, String role, String phoneNumber) async {
    await _firestore.collection('users').doc(uid).set({
      'phoneNumber': phoneNumber,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get User Profile (Full object)
  Future<user_model.User?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = user.uid; // Ensure ID is present
        return user_model.User.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  // Update Profile
  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
     try {
       final user = _auth.currentUser;
       if (user == null) return;
       
       final updates = <String, dynamic>{};
       if (fullName != null) updates['full_name'] = fullName;
       if (avatarUrl != null) updates['profile_url'] = avatarUrl;
       
       if (updates.isNotEmpty) {
           await _firestore.collection('users').doc(user.uid).update(updates);
       }
     } catch (e) {
       debugPrint('Error updating profile: $e');
       throw e;
     }
  }

  // Legacy adapter for login form widget
  Future<void> signInWithPhone(String phoneNumber) async {
      // Logic handled in UI via verifyPhoneNumber, this is a placeholder if needed
      // or we can remove this if we fix the UI call site.
      // But since check failed on undefined method:
      throw UnimplementedError("Use verifyPhoneNumber with callbacks instead");
  }

  // Legacy adapter
  Future<UserCredential> verifyOtp({required String phone, required String token}) async {
     // This signature assumes we have verificationId stored somewhere or passed differently
     throw UnimplementedError("Use signInWithOTP with verificationId");
  }
  
  // Create or Update Profile (merged)
  Future<void> createOrUpdateUserProfile(user_model.User user) async {
       await _firestore.collection('users').doc(user.id).set(user.toJson(), SetOptions(merge: true));
  }

  // Get Current User
  User? get currentUser => _auth.currentUser;

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
