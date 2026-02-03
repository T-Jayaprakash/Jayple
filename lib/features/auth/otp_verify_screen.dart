import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../core/auth/phone_auth_service.dart';
import '../../core/auth/auth_controller.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _service = PhoneAuthService();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  int _seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_seconds == 0) return t.cancel();
      setState(() => _seconds--);
    });
  }

  void _verify() async {
    if (_otpController.text.length != 6) return;
    setState(() { _isLoading = true; _error = null; });
    
    try {
      await _service.verifyOtp(_otpController.text);
      // No navigation. AuthGate handles it.
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }
  
  void _resend() {
     _service.verifyPhoneNumber(AuthController.instance.phoneNumber!);
     setState(() => _seconds = 30);
     _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Verify OTP"), 
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
             // Reset state to unauthenticated to go back
             AuthController.instance.clearOtpState();
             AuthController.instance.status.value = AuthStatus.unauthenticated;
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("Code sent to ${AuthController.instance.phoneNumber}"),
            const SizedBox(height: 20),
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _otpController,
              onCompleted: (_) => _verify(),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            if (_seconds > 0)
              Text("Resend in $_seconds")
            else
              TextButton(onPressed: _resend, child: const Text("Resend OTP")),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                child: _isLoading ? const CircularProgressIndicator() : const Text("Verify"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
