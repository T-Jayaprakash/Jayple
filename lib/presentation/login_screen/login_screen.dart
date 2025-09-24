import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../services/auth_service.dart';
import 'widgets/otp_pin_field.dart';
import 'complete_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isOtpStep = false;
  String _phone = '';
  final TextEditingController _otpController = TextEditingController();

  Future<void> _handleSendOtp() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithPhone(_phone);
      setState(() => _isOtpStep = true);
      _showErrorMessage('OTP sent to $_phone');
    } catch (e) {
      _showErrorMessage('Failed to send OTP. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() => _isLoading = true);
    try {
      final response = await AuthService.instance
          .verifyOtp(phone: _phone, token: _otpController.text.trim());
      if (response.user != null) {
        HapticFeedback.mediumImpact();
        // Check if user profile exists in users table
        final profile = await AuthService.instance.getUserProfile();
        if (profile != null) {
          // Profile exists, go directly to home
          Navigator.pushReplacementNamed(context, '/customer-home-screen');
        } else {
          // No profile, go to complete profile
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CompleteProfileScreen(phone: _phone),
            ),
          );
        }
      } else {
        _showErrorMessage('Invalid OTP. Please try again.');
      }
    } catch (e) {
      _showErrorMessage('OTP verification failed. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    // No-op: console messages/snackbars removed as per request
  }

  void _navigateToSignUp() {
    Navigator.pushNamed(context, '/onboarding-flow');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 8.h),
                  // App Logo
                  Container(
                    width: 25.w,
                    height: 25.w,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'J',
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  // Welcome Text
                  Text(
                    'Welcome to Jayple',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Your trusted salon & grooming partner',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: 6.h),
                  // Phone Login Step
                  if (!_isOtpStep) ...[
                    TextField(
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixText: '+91 ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _phone =
                          '+91${val.replaceAll(RegExp(r'[^0-9]'), '')}',
                      enabled: !_isLoading,
                    ),
                    SizedBox(height: 2.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSendOtp,
                        child: _isLoading
                            ? CircularProgressIndicator()
                            : Text('Send OTP'),
                      ),
                    ),
                  ]
                  // OTP Step
                  else ...[
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
                        child: _isLoading
                            ? CircularProgressIndicator()
                            : Text('Verify OTP'),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _isOtpStep = false),
                      child: Text('Edit phone number'),
                    ),
                  ],
                  Spacer(),
                  // Sign Up Link
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New user? ',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        GestureDetector(
                          onTap: _isLoading ? null : _navigateToSignUp,
                          child: Text(
                            'Sign Up',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
