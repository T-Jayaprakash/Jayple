import 'package:flutter/material.dart';

import 'package:intl_phone_field/intl_phone_field.dart';
import '../../services/auth_service.dart';
import 'otp_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _completePhoneNumber = "";
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendOtp() async {
    if (_completePhoneNumber.isEmpty || _completePhoneNumber.length < 10) {
      setState(() => _errorMessage = "Enter a valid phone number");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Logic delegated to AuthService (Strict Orchestration)
      await AuthService.instance.sendOtp(
        context: context,
        phoneNumber: _completePhoneNumber,
      );
      
      // Note: Navigation happens inside AuthService.sendOtp > codeSent callback
      // We stop loading here when the *initial* async call returns or completes
      // Actually, verifyPhoneNumber is async but the callbacks happen later.
      // However, the function returns void immediately or after setup.
      // We should probably keep loading true? 
      // No, verifyPhoneNumber returns 'Future<void>' which completes when the verification process *starts*.
      // So we should set loading to false? No, we want to block until navigation.
      // But we can't await the callback here. 
      // Standard pattern: keep loading until context changes (navigation) or error.
      // But since we navigate in callback, this widget might be in the stack.
      // Simple fix: set isLoading = false after some timeout or let the new screen cover it.
      // Better: The user can retry if it fails.
      
      // Since we don't await the *result* (OTP sent), we assume success-initiation.
      // But if we want to show a spinner UNTIL code is sent, we need the callback to notify us.
      // Since AuthService handles navigation, this widget will lose top focus.
      
      setState(() => _isLoading = false);

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Login'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Jayple',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your phone number to continue',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            
            IntlPhoneField(
              controller: _phoneController,
              initialCountryCode: 'IN',
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterText: "",
              ),
              languageCode: "en",
              onChanged: (phone) {
                _completePhoneNumber = phone.completeNumber;
              },
              onCountryChanged: (country) {
                // Handle if needed
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Send Code'),
              ),
            ),
            
            const SizedBox(height: 24),
            Center(
              child: Text(
                'By continuing, you agree to our Terms & Conditions',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
