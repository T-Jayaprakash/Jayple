import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class OtpPinField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String)? onCompleted;
  const OtpPinField({
    Key? key,
    required this.controller,
    this.enabled = true,
    this.onCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PinCodeTextField(
      appContext: context,
      length: 6,
      controller: controller,
      animationType: AnimationType.fade,
      keyboardType: TextInputType.number,
      autoFocus: true,
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(10),
        fieldHeight: 50,
        fieldWidth: 40,
        activeColor: Theme.of(context).primaryColor,
        selectedColor: Theme.of(context).colorScheme.secondary,
        inactiveColor: Theme.of(context).colorScheme.outline,
      ),
      animationDuration: const Duration(milliseconds: 200),
      enableActiveFill: false,
      onCompleted: onCompleted,
      enabled: enabled,
      onChanged: (_) {},
      beforeTextPaste: (text) => false,
      showCursor: true,
    );
  }
}
