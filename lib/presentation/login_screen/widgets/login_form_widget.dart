import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import 'otp_pin_field.dart';

class LoginFormWidget extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onSignUpTap;

  const LoginFormWidget({
    Key? key,
    this.onLoginSuccess,
    this.onSignUpTap,
  }) : super(key: key);

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isOtpStep = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _verificationId;

  Future<void> _handleSendOtp() async {
    setState(() => _isLoading = true);
    final phone = '+91${_phoneController.text.replaceAll(RegExp(r'[^0-9]'), '')}';
    
    await AuthService.instance.verifyPhoneNumber(
      phoneNumber: phone,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isOtpStep = true;
          _isLoading = false;
        });
        _showMessage('OTP sent to $phone');
      },
      onVerificationFailed: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showMessage('Verification failed: ${e.message}');
      },
      onCodeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _handleVerifyOtp() async {
    if (_verificationId == null) return;
    setState(() => _isLoading = true);
    try {
      final credential = await AuthService.instance.signInWithOTP(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      
      if (credential.user != null) {
        HapticFeedback.mediumImpact();
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      _showMessage('OTP verification failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 3.h),
        if (!_isOtpStep) ...[
          Text(
            "Phone Number",
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 1.h),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: "Enter your phone number",
              prefixText: '+91 ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            enabled: !_isLoading,
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            height: 6.h,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lightTheme.primaryColor,
                foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.lightTheme.colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Text(
                      "Send OTP",
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTheme.colorScheme.onPrimary,
                      ),
                    ),
            ),
          ),
        ] else ...[
          Text(
            "Enter OTP",
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 1.h),
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
            height: 6.h,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lightTheme.primaryColor,
                foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.lightTheme.colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Text(
                      "Verify OTP",
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTheme.colorScheme.onPrimary,
                      ),
                    ),
            ),
          ),
          TextButton(
            onPressed:
                _isLoading ? null : () => setState(() => _isOtpStep = false),
            child: Text('Edit phone number'),
          ),
        ],
        SizedBox(height: 2.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: widget.onSignUpTap,
              child: Text(
                "Sign Up",
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
// ...existing code ends above. Removed duplicate/extra widget tree.
