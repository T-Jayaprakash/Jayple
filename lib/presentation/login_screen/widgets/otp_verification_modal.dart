import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class OtpVerificationModal extends StatefulWidget {
  final String phoneNumber;
  final Function(String) onVerifyOtp;
  final Function() onResendOtp;
  final bool isLoading;

  const OtpVerificationModal({
    Key? key,
    required this.phoneNumber,
    required this.onVerifyOtp,
    required this.onResendOtp,
    required this.isLoading,
  }) : super(key: key);

  @override
  State<OtpVerificationModal> createState() => _OtpVerificationModalState();
}

class _OtpVerificationModalState extends State<OtpVerificationModal>
    with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;
  int _resendTimer = 30;
  bool _canResend = false;
  String _otpCode = '';

  @override
  void initState() {
    super.initState();
    _initializeTimer();
    _listenForSms();
  }

  void _initializeTimer() {
    _timerController = AnimationController(
      duration: Duration(seconds: 30),
      vsync: this,
    );

    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _timerController,
      curve: Curves.linear,
    ));

    _timerController.addListener(() {
      setState(() {
        _resendTimer = (30 * _timerAnimation.value).ceil();
        if (_resendTimer == 0) {
          _canResend = true;
        }
      });
    });

    _timerController.forward();
  }

  void _listenForSms() async {
    try {
      await SmsAutoFill().listenForCode();
    } catch (e) {
      // SMS autofill not available, continue without it
    }
  }

  void _handleOtpChange(String? value) {
    setState(() {
      _otpCode = value ?? '';
    });

    if ((value ?? '').length == 6) {
      // Auto-verify when 6 digits are entered
      _verifyOtp();
    }
  }

  void _verifyOtp() {
    if (_otpCode.length == 6 && !widget.isLoading) {
      HapticFeedback.lightImpact();
      widget.onVerifyOtp(_otpCode);
    }
  }

  void _resendOtp() {
    if (_canResend && !widget.isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        _canResend = false;
        _resendTimer = 30;
        _otpCode = '';
        _otpController.clear();
      });

      _timerController.reset();
      _timerController.forward();
      widget.onResendOtp();
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    _otpController.dispose();
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Handle bar
          Container(
            width: 12.w,
            height: 4,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          SizedBox(height: 3.h),

          // Title
          Text(
            'Verify Phone Number',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),

          SizedBox(height: 2.h),

          // Description
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              children: [
                TextSpan(text: 'We\'ve sent a 6-digit verification code to\n'),
                TextSpan(
                  text: widget.phoneNumber,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // OTP Input Field
          PinFieldAutoFill(
            controller: _otpController,
            decoration: UnderlineDecoration(
              textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              colorBuilder: FixedColorBuilder(
                Theme.of(context).colorScheme.primary,
              ),
              bgColorBuilder: FixedColorBuilder(
                Theme.of(context).colorScheme.surface,
              ),
              lineHeight: 2,
              gapSpace: 4.w,
            ),
            currentCode: _otpCode,
            onCodeSubmitted: (code) {
              setState(() {
                _otpCode = code;
              });
            },
            onCodeChanged: _handleOtpChange,
            codeLength: 6,
          ),

          SizedBox(height: 4.h),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 6.h,
            child: ElevatedButton(
              onPressed: (_otpCode.length == 6 && !widget.isLoading)
                  ? _verifyOtp
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: (_otpCode.length == 6)
                    ? AppTheme.lightTheme.primaryColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                elevation: (_otpCode.length == 6) ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Verify OTP',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
            ),
          ),

          SizedBox(height: 3.h),

          // Resend OTP
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Didn\'t receive the code? ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              TextButton(
                onPressed: _canResend ? _resendOtp : null,
                child: Text(
                  _canResend ? 'Resend' : 'Resend in ${_resendTimer}s',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _canResend
                            ? AppTheme.lightTheme.primaryColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),

          SizedBox(height: 2.h),
        ],
      ),
    );
  }
}