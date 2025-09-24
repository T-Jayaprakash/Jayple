import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/booking_summary_widget.dart';
import './widgets/customer_details_widget.dart';
import './widgets/date_time_selection_widget.dart';
import './widgets/payment_section_widget.dart';
import './widgets/progress_indicator_widget.dart';
import './widgets/service_selection_widget.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({Key? key}) : super(key: key);

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;
  final List<String> _stepTitles = [
    'Select Services',
    'Choose Date & Time',
    'Customer Details',
    'Payment & Confirmation'
  ];

  // Step 1: Service Selection
  List<Map<String, dynamic>> _selectedServices = [
    {
      'id': '1',
      'name': 'Premium Haircut & Styling',
      'price': '₹500',
      'image':
          'https://images.pexels.com/photos/3993449/pexels-photo-3993449.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1',
      'quantity': 1,
    },
    {
      'id': '2',
      'name': 'Beard Trim & Shaping',
      'price': '₹200',
      'image':
          'https://images.pexels.com/photos/8142019/pexels-photo-8142019.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1',
      'quantity': 1,
    },
  ];

  // Step 2: Date & Time Selection
  DateTime? _selectedDate;
  String? _selectedTime;

  // Step 3: Customer Details
  String _customerName = 'Rajesh Kumar';
  String _customerPhone = '+91 9876543210';
  String _specialRequests = '';

  // Step 4: Payment
  String _selectedPaymentMethod = 'razorpay';
  Map<String, String> _cardDetails = {};

  // Provider Info
  final Map<String, dynamic> _providerInfo = {
    'name': 'Elite Salon & Spa',
    'type': 'Premium Salon',
    'image':
        'https://images.pexels.com/photos/3993449/pexels-photo-3993449.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1',
    'rating': 4.8,
    'reviews': 245,
    'address': 'T. Nagar, Chennai',
  };

  bool _isLoading = false;
  bool _showSuccessAnimation = false;
  String? _bookingConfirmationNumber;

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return _selectedServices.isNotEmpty;
      case 1:
        return _selectedDate != null && _selectedTime != null;
      case 2:
        return _customerName.trim().isNotEmpty &&
            _customerPhone.trim().isNotEmpty &&
            _customerPhone.length >= 10;
      case 3:
        if (_selectedPaymentMethod == 'new_card') {
          return _cardDetails['number']?.isNotEmpty == true &&
              _cardDetails['expiry']?.isNotEmpty == true &&
              _cardDetails['cvv']?.isNotEmpty == true &&
              _cardDetails['name']?.isNotEmpty == true;
        }
        return _selectedPaymentMethod.isNotEmpty;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_canProceedToNextStep()) {
      if (_currentStep < _totalSteps - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        _processBooking();
      }
    } else {
      _showValidationError();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _showValidationError() {
    String message = '';
    switch (_currentStep) {
      case 0:
        message = 'Please select at least one service';
        break;
      case 1:
        message = 'Please select date and time';
        break;
      case 2:
        message = 'Please fill in all required customer details';
        break;
      case 3:
        message = 'Please complete payment information';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _processBooking() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 3));

    // Generate confirmation number
    _bookingConfirmationNumber =
        'JYP${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    setState(() {
      _isLoading = false;
      _showSuccessAnimation = true;
    });

    // Show success dialog after animation
    await Future.delayed(const Duration(seconds: 2));
    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(
                iconName: 'check_circle',
                size: 40,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Booking Confirmed!',
              style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Confirmation Number: $_bookingConfirmationNumber',
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Your booking has been confirmed. You will receive SMS confirmation shortly.',
              style: AppTheme.lightTheme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Add to calendar functionality would go here
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    child: Text('Add to Calendar'),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/customer-home-screen',
                        (route) => false,
                      );
                    },
                    child: Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return ServiceSelectionWidget(
          selectedServices: _selectedServices,
          onServicesChanged: (services) {
            setState(() {
              _selectedServices = services;
            });
          },
        );
      case 1:
        return DateTimeSelectionWidget(
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
          onTimeSelected: (time) {
            setState(() {
              _selectedTime = time;
            });
          },
        );
      case 2:
        return CustomerDetailsWidget(
          name: _customerName,
          phone: _customerPhone,
          specialRequests: _specialRequests,
          onNameChanged: (name) {
            setState(() {
              _customerName = name;
            });
          },
          onPhoneChanged: (phone) {
            setState(() {
              _customerPhone = phone;
            });
          },
          onSpecialRequestsChanged: (requests) {
            setState(() {
              _specialRequests = requests;
            });
          },
        );
      case 3:
        return Column(
          children: [
            BookingSummaryWidget(
              selectedServices: _selectedServices,
              selectedDate: _selectedDate,
              selectedTime: _selectedTime,
              customerName: _customerName,
              customerPhone: _customerPhone,
              specialRequests: _specialRequests,
              providerInfo: _providerInfo,
            ),
            SizedBox(height: 3.h),
            PaymentSectionWidget(
              selectedPaymentMethod: _selectedPaymentMethod,
              onPaymentMethodChanged: (method) {
                setState(() {
                  _selectedPaymentMethod = method;
                });
              },
              cardDetails: _cardDetails,
              onCardDetailsChanged: (details) {
                setState(() {
                  _cardDetails = details;
                });
              },
            ),
          ],
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Book Appointment'),
        leading: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            size: 24,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_currentStep < _totalSteps - 1)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              ProgressIndicatorWidget(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
                stepTitles: _stepTitles,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(4.w),
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(6.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.lightTheme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Processing Payment...',
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Please wait while we confirm your booking',
                          style: AppTheme.lightTheme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Success Animation Overlay
          if (_showSuccessAnimation)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(6.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(seconds: 1),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 20.w,
                                height: 20.w,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: CustomIconWidget(
                                  iconName: 'check_circle',
                                  size: 40,
                                  color: Colors.green,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Payment Successful!',
                          style: AppTheme.lightTheme.textTheme.titleLarge
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: AppTheme.lightTheme.shadowColor,
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousStep,
                    child: Text('Back'),
                  ),
                ),
              if (_currentStep > 0) SizedBox(width: 4.w),
              Expanded(
                flex: _currentStep > 0 ? 1 : 2,
                child: ElevatedButton(
                  onPressed: _canProceedToNextStep() ? _nextStep : null,
                  child: Text(
                    _currentStep == _totalSteps - 1
                        ? 'Confirm Booking'
                        : 'Continue',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
