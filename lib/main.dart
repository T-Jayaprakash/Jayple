import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // App Check (Play Integrity) - Strict
  // We wrap in try-catch to avoid crash if already active or other issues,
  // but strictly use PlayIntegrity on Android.
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      // For iOS/Web if needed later:
      // appleProvider: AppleProvider.deviceCheck,
      // webProvider: ReCaptchaV3Provider('recaptcha-site-key'),
    );
  } catch (e) {
    // Fail silently in production logic as per requirement "Fail silently if already configured"
  }
  runApp(const MyApp());
}
