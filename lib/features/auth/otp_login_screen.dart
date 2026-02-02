import 'package:flutter/material.dart';

class OtpLoginScreen extends StatelessWidget {
  const OtpLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('OTP Login Screen (Placeholder)'),
            SizedBox(height: 20),
            Text('Authentication logic will be implemented in next step.'),
          ],
        ),
      ),
    );
  }
}
