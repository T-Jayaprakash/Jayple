import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class PaymentSectionWidget extends StatefulWidget {
  final String selectedPaymentMethod;
  final Function(String) onPaymentMethodChanged;
  final Map<String, String> cardDetails;
  final Function(Map<String, String>) onCardDetailsChanged;

  const PaymentSectionWidget({
    Key? key,
    required this.selectedPaymentMethod,
    required this.onPaymentMethodChanged,
    required this.cardDetails,
    required this.onCardDetailsChanged,
  }) : super(key: key);

  @override
  State<PaymentSectionWidget> createState() => _PaymentSectionWidgetState();
}

class _PaymentSectionWidgetState extends State<PaymentSectionWidget> {
  late TextEditingController _cardNumberController;
  late TextEditingController _expiryController;
  late TextEditingController _cvvController;
  late TextEditingController _nameController;

  final List<Map<String, dynamic>> _savedCards = [
    {
      'id': '1',
      'last4': '4242',
      'brand': 'Visa',
      'expiry': '12/25',
    },
    {
      'id': '2',
      'last4': '5555',
      'brand': 'Mastercard',
      'expiry': '08/26',
    },
  ];

  @override
  void initState() {
    super.initState();
    _cardNumberController =
        TextEditingController(text: widget.cardDetails['number'] ?? '');
    _expiryController =
        TextEditingController(text: widget.cardDetails['expiry'] ?? '');
    _cvvController =
        TextEditingController(text: widget.cardDetails['cvv'] ?? '');
    _nameController =
        TextEditingController(text: widget.cardDetails['name'] ?? '');
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _updateCardDetails() {
    widget.onCardDetailsChanged({
      'number': _cardNumberController.text,
      'expiry': _expiryController.text,
      'cvv': _cvvController.text,
      'name': _nameController.text,
    });
  }

  String _formatCardNumber(String value) {
    value = value.replaceAll(' ', '');
    String formatted = '';
    for (int i = 0; i < value.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += value[i];
    }
    return formatted;
  }

  String _formatExpiry(String value) {
    value = value.replaceAll('/', '');
    if (value.length >= 2) {
      return '${value.substring(0, 2)}/${value.substring(2)}';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),

        // Digital Wallets
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'apple_pay',
                groupValue: widget.selectedPaymentMethod,
                onChanged: (value) => widget.onPaymentMethodChanged(value!),
                title: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'apple',
                      size: 24,
                      color: Colors.black,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Apple Pay',
                      style: AppTheme.lightTheme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              RadioListTile<String>(
                value: 'google_pay',
                groupValue: widget.selectedPaymentMethod,
                onChanged: (value) => widget.onPaymentMethodChanged(value!),
                title: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'g_mobiledata',
                      size: 24,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Google Pay',
                      style: AppTheme.lightTheme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              RadioListTile<String>(
                value: 'razorpay',
                groupValue: widget.selectedPaymentMethod,
                onChanged: (value) => widget.onPaymentMethodChanged(value!),
                title: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'payment',
                      size: 24,
                      color: AppTheme.lightTheme.primaryColor,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Razorpay',
                      style: AppTheme.lightTheme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 2.h),

        // Saved Cards
        if (_savedCards.isNotEmpty) ...[
          Text(
            'Saved Cards',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _savedCards.map((card) {
                return Column(
                  children: [
                    RadioListTile<String>(
                      value: 'saved_${card['id']}',
                      groupValue: widget.selectedPaymentMethod,
                      onChanged: (value) =>
                          widget.onPaymentMethodChanged(value!),
                      title: Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'credit_card',
                            size: 24,
                            color: AppTheme.lightTheme.primaryColor,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${card['brand']} •••• ${card['last4']}',
                                  style:
                                      AppTheme.lightTheme.textTheme.titleMedium,
                                ),
                                Text(
                                  'Expires ${card['expiry']}',
                                  style: AppTheme.lightTheme.textTheme.bodySmall
                                      ?.copyWith(
                                    color: AppTheme
                                        .lightTheme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (card != _savedCards.last) Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 2.h),
        ],

        // New Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'new_card',
                groupValue: widget.selectedPaymentMethod,
                onChanged: (value) => widget.onPaymentMethodChanged(value!),
                title: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'add_card',
                      size: 24,
                      color: AppTheme.lightTheme.primaryColor,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Add New Card',
                      style: AppTheme.lightTheme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (widget.selectedPaymentMethod == 'new_card') ...[
                Divider(height: 1),
                Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cardNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final formatted = _formatCardNumber(newValue.text);
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                  offset: formatted.length),
                            );
                          }),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Card Number',
                          hintText: '1234 5678 9012 3456',
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(3.w),
                            child: CustomIconWidget(
                              iconName: 'credit_card',
                              size: 20,
                              color: AppTheme.lightTheme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        onChanged: (value) => _updateCardDetails(),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                                TextInputFormatter.withFunction(
                                    (oldValue, newValue) {
                                  final formatted =
                                      _formatExpiry(newValue.text);
                                  return TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                        offset: formatted.length),
                                  );
                                }),
                              ],
                              decoration: InputDecoration(
                                labelText: 'MM/YY',
                                hintText: '12/25',
                              ),
                              onChanged: (value) => _updateCardDetails(),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: TextFormField(
                              controller: _cvvController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: InputDecoration(
                                labelText: 'CVV',
                                hintText: '123',
                              ),
                              onChanged: (value) => _updateCardDetails(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Cardholder Name',
                          hintText: 'John Doe',
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(3.w),
                            child: CustomIconWidget(
                              iconName: 'person',
                              size: 20,
                              color: AppTheme.lightTheme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        onChanged: (value) => _updateCardDetails(),
                      ),
                      SizedBox(height: 2.h),
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: AppTheme.lightTheme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.lightTheme.dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'security',
                              size: 20,
                              color: Colors.green,
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                'Your payment information is encrypted and secure',
                                style: AppTheme.lightTheme.textTheme.bodySmall
                                    ?.copyWith(
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
