import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/auth/user_model.dart' as auth_model;
import '../features/auth/auth_controller.dart';
import '../features/auth/otp_screen.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();

  factory AuthService() {
    return instance;
  }

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Send OTP (Strict Orchestration)
  Future<void> sendOtp({
    required BuildContext context,
    required String phoneNumber,
    bool silent = false, // If true, won't navigate (for resend)
  }) async {
    // Prevent re-triggering if already sent to same number recently?
    // For now, we trust the UI to disable buttons, but we clear state first.
    AuthController.instance.setPhoneNumber(phoneNumber);
    
    // Show loader? - handled by UI usually, but we could show dialog if strictly required. 
    // Assuming UI shows loader while awaiting this Future.

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: AuthController.instance.resendToken,
      
      // A. Verification Completed (Auto-resolve)
      verificationCompleted: (PhoneAuthCredential credential) async {
        debugPrint('AuthService: Auto-verification completed');
        await _signInWithCredential(context, credential);
      },

      // B. Verification Failed
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('AuthService: Verification Failed: ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${e.message}')),
        );
      },

      // C. Code Sent (Navigate HERE)
      codeSent: (String verificationId, int? resendToken) {
        debugPrint('AuthService: Code Sent. Silent: $silent');
        AuthController.instance.setVerificationId(verificationId);
        AuthController.instance.setResendToken(resendToken);

        if (!silent) {
          // Navigate ONLY if not silent
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OtpScreen(),
            ),
          );
        } else {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('OTP Resent Successfully')),
             );
        }
      },

      // D. Timeout
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('AuthService: Timeout. VerificationId: $verificationId');
        AuthController.instance.setVerificationId(verificationId);
      },
    );
  }

  // 2. Verify OTP
  Future<void> verifyOtp({
    required BuildContext context,
    required String otp,
  }) async {
    final verId = AuthController.instance.verificationId;
    if (verId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No Verification ID found')),
      );
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verId,
      smsCode: otp,
    );

    await _signInWithCredential(context, credential);
  }

  // Internal Sign-In Helper
  Future<void> _signInWithCredential(BuildContext context, PhoneAuthCredential credential) async {
    try {
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await ensureUserDocumentExists(userCredential.user!);
        
        // Navigation is handled by AuthGate automatically when auth state changes.
        // But if we are deep in the stack, we might want to pop to root.
        // However, AuthGate is usually the root. 
        // We will pop the OTP screen to let AuthGate take over or just let AuthGate rebuild.
        // Better: Pop until first route? No, AuthGate will switch the tree.
        // We just need to stop the loader.
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Failed: ${e.message}')),
      );
    }
  }

  // 3. Sync User to Firestore (Requirement 4)
  Future<void> ensureUserDocumentExists(User firebaseUser) async {
    final userRef = _firestore.collection('users').doc(firebaseUser.uid);
    final doc = await userRef.get();

    final Map<String, dynamic> userData = {
      'uid': firebaseUser.uid,
      'phoneNumber': firebaseUser.phoneNumber,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'role': 'user',
      'roles': ['user'],
      'status': 'active',
      'isBlocked': false,
    };

    if (!doc.exists) {
      userData['createdAt'] = FieldValue.serverTimestamp();
      await userRef.set(userData);
    } else {
      await userRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'phoneNumber': firebaseUser.phoneNumber,
      });
    }
  }

  // Fetch AppUser for AuthGate
  Future<auth_model.AppUser> fetchUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      final user = _auth.currentUser;
      if (user != null && user.uid == uid) {
        await ensureUserDocumentExists(user);
        final freshDoc = await _firestore.collection('users').doc(uid).get();
        return auth_model.AppUser.fromFirestore(freshDoc.data()!, uid);
      }
      throw Exception('User document not found');
    }
    return auth_model.AppUser.fromFirestore(doc.data()!, uid);
  }

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    AuthController.instance.clear();
    await _auth.signOut();
  }
}
