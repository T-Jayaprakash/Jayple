import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus {
  unauthenticated,
  otpSent,
  authenticated,
}

/// Single Source of Truth for Auth State
/// Do NOT put UI logic here.
class AuthController {
  static final AuthController instance = AuthController._internal();

  factory AuthController() {
    return instance;
  }

  AuthController._internal() {
    // Listen to Firebase Auth state only
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        status.value = AuthStatus.authenticated;
        clearOtpState();
      } else {
        // Only revert to unauthenticated if we aren't in the middle of OTP flow
        // But if Firebase says null, we are unauthenticated.
        // However, we might be 'otpSent' state (which is technically unauthenticated in Firebase).
        // So we only force 'unauthenticated' if we aren't manually set to otpSent?
        // Actually, if Firebase emits null, it means no session.
        // If we are waiting for OTP, we are also null.
        // So we shouldn't overwrite 'otpSent' unless explicitly signing out?
        if (status.value != AuthStatus.otpSent) {
           status.value = AuthStatus.unauthenticated;
        }
      }
    });
  }

  // Reactive State
  final ValueNotifier<AuthStatus> status = ValueNotifier(AuthStatus.unauthenticated);
  
  // OTP State (Transient)
  String? _verificationId;
  int? _resendToken;
  String? _phoneNumber;

  // Getters
  String? get verificationId => _verificationId;
  int? get resendToken => _resendToken;
  String? get phoneNumber => _phoneNumber;

  // State Modifiers
  void setOtpSent({required String verificationId, int? resendToken, required String phoneNumber}) {
    _verificationId = verificationId;
    _resendToken = resendToken;
    _phoneNumber = phoneNumber;
    status.value = AuthStatus.otpSent;
  }

  void clearOtpState() {
    _verificationId = null;
    _resendToken = null;
    _phoneNumber = null;
    // Status update logic handled by listener or manual set if needed
  }
  
  void signOut() {
    status.value = AuthStatus.unauthenticated;
    clearOtpState();
    FirebaseAuth.instance.signOut();
  }
}
