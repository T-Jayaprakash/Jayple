import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../core/auth/phone_auth_service.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _service = PhoneAuthService();
  String _phoneNumber = '';
  bool _isLoading = false;
  String? _error;

  void _submit() async {
    if (_phoneNumber.length < 10) return;
    
    setState(() { _isLoading = true; _error = null; });

    try {
      await _service.verifyPhoneNumber(_phoneNumber);
      // No navigation needed. AuthGate will switch screen when status changes.
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Login"), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Enter Phone Number", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            IntlPhoneField(
              initialCountryCode: 'IN',
              onChanged: (phone) => _phoneNumber = phone.completeNumber,
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator() : const Text("Send OTP"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
