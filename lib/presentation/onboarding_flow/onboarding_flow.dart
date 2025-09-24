import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/onboarding_card_widget.dart';
import './widgets/page_indicator_widget.dart';
import './widgets/role_selection_card_widget.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({Key? key}) : super(key: key);

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedRole;
  bool _isRoleSelectionPage = false;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": "Discover Services Near You",
      "description":
          "Find the best salons and freelance barbers in your area with just a few taps. Browse services, check ratings, and book instantly.",
      "imageUrl":
          "https://images.pexels.com/photos/3993449/pexels-photo-3993449.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
    },
    {
      "title": "Book with Confidence",
      "description":
          "Schedule appointments at your convenience with real-time availability. Get instant confirmations and track your booking status.",
      "imageUrl":
          "https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=1000&q=80",
    },
    {
      "title": "Secure & Easy Payments",
      "description":
          "Pay safely with multiple payment options including Razorpay and Stripe. Enjoy cashless transactions with complete security.",
      "imageUrl":
          "https://images.pixabay.com/photos/4481970/pexels-photo-4481970.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
    },
  ];

  final List<Map<String, dynamic>> _roleData = [
    {
      "title": "Customer",
      "description": "Book services from nearby salons and freelance barbers",
      "iconName": "person",
      "role": "customer",
    },
    {
      "title": "Vendor",
      "description": "Manage your salon and accept bookings from customers",
      "iconName": "store",
      "role": "vendor",
    },
    {
      "title": "Freelancer",
      "description": "Offer mobile services and grow your client base",
      "iconName": "work",
      "role": "freelancer",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showRoleSelection();
    }
  }

  void _skipOnboarding() {
    _showRoleSelection();
  }

  void _showRoleSelection() {
    setState(() {
      _isRoleSelectionPage = true;
    });
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
    });
  }

  void _continueWithRole() {
    if (_selectedRole != null) {
      HapticFeedback.mediumImpact();
      Navigator.pushReplacementNamed(context, '/login-screen');
    }
  }

  void _goBackToOnboarding() {
    setState(() {
      _isRoleSelectionPage = false;
      _selectedRole = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: _isRoleSelectionPage
          ? _buildRoleSelectionPage()
          : _buildOnboardingPages(),
    );
  }

  Widget _buildOnboardingPages() {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemCount: _onboardingData.length,
          itemBuilder: (context, index) {
            final data = _onboardingData[index];
            return OnboardingCardWidget(
              title: data["title"] as String,
              description: data["description"] as String,
              imageUrl: data["imageUrl"] as String,
              isActive: index == _currentPage,
            );
          },
        ),
        Positioned(
          bottom: 12.h,
          left: 0,
          right: 0,
          child: Column(
            children: [
              PageIndicatorWidget(
                currentPage: _currentPage,
                totalPages: _onboardingData.length,
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _skipOnboarding,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style:
                            AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          color:
                              AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppTheme.lightTheme.colorScheme.primary,
                        foregroundColor:
                            AppTheme.lightTheme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == _onboardingData.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                              color: AppTheme.lightTheme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          CustomIconWidget(
                            iconName: 'arrow_forward',
                            color: AppTheme.lightTheme.colorScheme.onPrimary,
                            size: 5.w,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelectionPage() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goBackToOnboarding,
                  icon: CustomIconWidget(
                    iconName: 'arrow_back',
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                    size: 6.w,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 4.h),
                  Text(
                    'Choose Your Role',
                    style:
                        AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.lightTheme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Select how you want to use Jayple',
                    style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6.h),
                  ..._roleData
                      .map((role) => RoleSelectionCardWidget(
                            title: role["title"] as String,
                            description: role["description"] as String,
                            iconName: role["iconName"] as String,
                            isSelected: _selectedRole == role["role"],
                            onTap: () => _selectRole(role["role"] as String),
                          ))
                      .toList(),
                  SizedBox(height: 6.h),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(6.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedRole != null ? _continueWithRole : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedRole != null
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.outline
                          .withValues(alpha: 0.3),
                  foregroundColor: _selectedRole != null
                      ? AppTheme.lightTheme.colorScheme.onPrimary
                      : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  padding: EdgeInsets.symmetric(vertical: 2.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _selectedRole != null ? 2 : 0,
                ),
                child: Text(
                  'Continue',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: _selectedRole != null
                        ? AppTheme.lightTheme.colorScheme.onPrimary
                        : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
