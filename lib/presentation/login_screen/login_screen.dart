import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';
import 'widgets/otp_pin_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isOtpStep = false;
  String _phone = '';
  String? _verificationId;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Future<void> _handleSendOtp() async {
    if (_phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Phone Number')));
      return;
    }
    setState(() => _isLoading = true);
    
    // Format phone number (Assuming India +91 for now as per previous code)
    String formattedPhone = '+91${_phone.replaceAll(RegExp(r'[^0-9]'), '')}';
    if (formattedPhone.length < 13) { 
        // Simple check +91 + 10 digits
        formattedPhone = _phone.startsWith('+') ? _phone : '+91$_phone';
    }

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isOtpStep = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP sent to $formattedPhone')));
        },
        onVerificationFailed: (e) {
             if (!mounted) return;
             setState(() => _isLoading = false);
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: ${e.message}')));
        },
        onCodeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (e) {
         if (!mounted) return;
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send OTP')));
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_verificationId == null || _otpController.text.length != 6) return;

    setState(() => _isLoading = true);
    try {
      UserCredential cred = await _authService.signInWithOTP(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      if (cred.user != null) {
        // Check Role
        String? role = await _authService.getUserRole(cred.user!.uid);
        if (!mounted) return;

        if (role != null) {
          // Navigate based on role
           switch (role) {
            case 'vendor':
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.vendorHome, (route) => false);
              break;
            case 'freelancer':
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.freelancerHome, (route) => false);
              break;
            case 'customer':
            default:
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.customerHome, (route) => false);
              break;
          }
        } else {
          // New User -> Role Selection
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.roleSelection, (route) => false);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid OTP: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSkip() {
    // Skip logic - Assume Customer Guest? Or just go to Role Selection?
    // User requested: "even they can skip initially"
    // Usually "Skip" implies browsing as Guest (Customer).
    Navigator.pushNamed(context, AppRoutes.customerHome); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _handleSkip,
            child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 5.h),
              Icon(Icons.phone_android, size: 80, color: Theme.of(context).primaryColor),
              SizedBox(height: 3.h),
              Text(
                'Welcome to Jayple',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Enter your phone number to continue',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              SizedBox(height: 6.h),
              
              if (!_isOtpStep) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _phone = val,
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendOtp,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Send OTP'),
                  ),
                ),
              ] else ...[
                OtpPinField(
                  controller: _otpController,
                  enabled: !_isLoading,
                  onCompleted: (val) {
                    if (val.length == 6 && !_isLoading) _handleVerifyOtp();
                  },
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Verify OTP'),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : () => setState(() => _isOtpStep = false),
                  child: const Text('Change Phone Number'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
