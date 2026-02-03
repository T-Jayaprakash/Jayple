import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_controller.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Verify Phone Number (Send OTP)
  Future<void> verifyPhoneNumber(String phoneNumber) async {
    debugPrint("PhoneAuthService: Verifying $phoneNumber");
    
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      // Force Android Retrievable token to prevent full flow restart if possible?
      // Actually forceResendingToken is for resend.
      forceResendingToken: AuthController.instance.resendToken,
      
      verificationCompleted: (PhoneAuthCredential credential) async {
        debugPrint("PhoneAuthService: Auto-verification completed");
        await _signIn(credential);
      },
      
      verificationFailed: (FirebaseAuthException e) {
        debugPrint("PhoneAuthService: Verification Failed ${e.code} - ${e.message}");
        // We throw to let UI show error
        throw e;
      },
      
      codeSent: (String verificationId, int? resendToken) {
        debugPrint("PhoneAuthService: Code Sent");
        // Update Single Source of Truth
        AuthController.instance.setOtpSent(
          verificationId: verificationId,
          resendToken: resendToken,
          phoneNumber: phoneNumber,
        );
      },
      
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint("PhoneAuthService: Timeout");
        // Update verId just in case
        // AuthController.instance.setVerificationId(verificationId); 
        // We need a method for this if we want to be strict, but setOtpSent works too if we keep other params.
        // For now, we ignore or treat as silent update.
      },
      
      timeout: const Duration(seconds: 60), 
    );
  }

  // 2. Verify OTP code
  Future<void> verifyOtp(String smsCode) async {
    final verId = AuthController.instance.verificationId;
    if (verId == null) throw FirebaseAuthException(code: 'dummy', message: "No Verification ID");

    final credential = PhoneAuthProvider.credential(
      verificationId: verId,
      smsCode: smsCode,
    );
    
    await _signIn(credential);
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    await _auth.signInWithCredential(credential);
    // State listener in AuthController will switch to 'authenticated' automatically
  }
}
