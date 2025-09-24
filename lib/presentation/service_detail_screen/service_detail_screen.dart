import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/about_section_widget.dart';
import './widgets/availability_calendar_widget.dart';
import './widgets/booking_bottom_sheet.dart';
import './widgets/location_card_widget.dart';
import './widgets/provider_info_card.dart';
import './widgets/reviews_section_widget.dart';
import './widgets/service_image_carousel.dart';
import './widgets/service_list_widget.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({Key? key}) : super(key: key);

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  DateTime? selectedDate;
  String? selectedTimeSlot;
  double totalPrice = 0.0;

  // Mock data for the service provider
  final Map<String, dynamic> providerData = {
    "id": 1,
    "name": "Elite Hair Studio",
    "type": "Premium Salon",
    "rating": 4.8,
    "reviewCount": 127,
    "isVerified": true,
    "images": [
      "https://images.unsplash.com/photo-1560066984-138dadb4c035?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3",
      "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3",
      "https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3",
    ],
  };

  final List<Map<String, dynamic>> servicesList = [
    {
      "id": 1,
      "name": "Premium Haircut & Styling",
      "price": "₹800",
      "duration": "45 min",
      "description":
          "Professional haircut with personalized styling consultation. Includes wash, cut, and blow-dry with premium products.",
      "isPopular": true,
    },
    {
      "id": 2,
      "name": "Beard Trim & Grooming",
      "price": "₹400",
      "duration": "30 min",
      "description":
          "Expert beard trimming and shaping with hot towel treatment and moisturizing.",
      "isPopular": false,
    },
    {
      "id": 3,
      "name": "Hair Wash & Conditioning",
      "price": "₹300",
      "duration": "20 min",
      "description":
          "Deep cleansing hair wash with premium conditioning treatment for healthy, shiny hair.",
      "isPopular": false,
    },
    {
      "id": 4,
      "name": "Complete Grooming Package",
      "price": "₹1200",
      "duration": "90 min",
      "description":
          "Full service package including haircut, beard trim, hair wash, styling, and face cleanup.",
      "isPopular": true,
    },
  ];

  final Map<String, dynamic> aboutData = {
    "bio":
        "Elite Hair Studio has been serving the community for over 8 years with exceptional grooming services. Our experienced stylists are trained in the latest techniques and use only premium products to ensure the best results for our clients.",
    "specialties": [
      "Men's Haircuts",
      "Beard Styling",
      "Hair Treatments",
      "Wedding Grooming"
    ],
    "experience": "8+ years in professional grooming",
    "certifications": [
      "Certified Hair Stylist",
      "Advanced Beard Grooming",
      "L'Oréal Professional"
    ],
  };

  final Map<String, dynamic> locationData = {
    "address": "123 MG Road, Brigade Road, Bangalore, Karnataka 560001",
    "distance": "2.3 km away",
    "isFreelancer": false,
    "serviceArea": "",
  };

  final List<Map<String, dynamic>> reviewsList = [
    {
      "id": 1,
      "customerName": "Rajesh Kumar",
      "rating": 5.0,
      "comment":
          "Excellent service! The haircut was exactly what I wanted. Very professional staff and clean environment.",
      "date": "2 days ago",
      "photos": [
        "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3",
      ],
    },
    {
      "id": 2,
      "customerName": "Arjun Patel",
      "rating": 4.0,
      "comment":
          "Good experience overall. The beard trim was perfect and the staff was friendly.",
      "date": "1 week ago",
      "photos": [],
    },
    {
      "id": 3,
      "customerName": "Vikram Singh",
      "rating": 5.0,
      "comment":
          "Best salon in the area! Always consistent quality and great customer service.",
      "date": "2 weeks ago",
      "photos": [
        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3",
      ],
    },
  ];

  final List<Map<String, dynamic>> availabilityData = [
    {
      "date": "2025-01-15",
      "timeSlots": [
        "9:00 AM",
        "10:00 AM",
        "11:00 AM",
        "2:00 PM",
        "3:00 PM",
        "4:00 PM",
        "5:00 PM"
      ],
    },
    {
      "date": "2025-01-16",
      "timeSlots": [
        "9:00 AM",
        "10:00 AM",
        "12:00 PM",
        "1:00 PM",
        "3:00 PM",
        "4:00 PM"
      ],
    },
    {
      "date": "2025-01-17",
      "timeSlots": ["10:00 AM", "11:00 AM", "2:00 PM", "4:00 PM", "5:00 PM"],
    },
    {
      "date": "2025-01-18",
      "timeSlots": [
        "9:00 AM",
        "11:00 AM",
        "1:00 PM",
        "2:00 PM",
        "3:00 PM",
        "5:00 PM"
      ],
    },
    {
      "date": "2025-01-19",
      "timeSlots": [],
    },
    {
      "date": "2025-01-20",
      "timeSlots": ["10:00 AM", "12:00 PM", "2:00 PM", "4:00 PM"],
    },
    {
      "date": "2025-01-21",
      "timeSlots": [
        "9:00 AM",
        "10:00 AM",
        "11:00 AM",
        "1:00 PM",
        "3:00 PM",
        "4:00 PM",
        "5:00 PM"
      ],
    },
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(height: 2.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: ProviderInfoCard(
                        providerData: providerData,
                        onReviewsTap: _scrollToReviews,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    ServiceListWidget(
                      services: servicesList,
                      onServiceTap: _onServiceTap,
                    ),
                    SizedBox(height: 2.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: AboutSectionWidget(
                        aboutData: aboutData,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: LocationCardWidget(
                        locationData: locationData,
                        onDirectionsTap: _openDirections,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: ReviewsSectionWidget(
                        reviews: reviewsList,
                        onViewAllTap: _viewAllReviews,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: AvailabilityCalendarWidget(
                        availabilityData: availabilityData,
                        onSlotSelected: _onSlotSelected,
                      ),
                    ),
                    SizedBox(height: 12.h), // Space for bottom booking bar
                  ],
                ),
              ),
            ],
          ),
          _buildBottomBookingBar(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 35.h,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      leading: Container(
        margin: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: CustomIconWidget(
              iconName: 'share',
              color: Colors.white,
              size: 24,
            ),
            onPressed: _shareProvider,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: ServiceImageCarousel(
          images: (providerData['images'] as List).cast<String>(),
          heroTag: 'provider_${providerData['id']}',
        ),
      ),
    );
  }

  Widget _buildBottomBookingBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: AppTheme.lightTheme.colorScheme.shadow,
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starting from',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '₹300',
                      style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.lightTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _showBookingBottomSheet,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                  ),
                  child: Text(
                    'Book Appointment',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onServiceTap(Map<String, dynamic> service) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${service['name']}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onSlotSelected(DateTime date, String timeSlot) {
    setState(() {
      selectedDate = date;
      selectedTimeSlot = timeSlot;
    });
  }

  void _scrollToReviews() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent * 0.7,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _openDirections() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening directions to ${locationData['address']}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _viewAllReviews() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing all ${reviewsList.length} reviews'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareProvider() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing ${providerData['name']}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showBookingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingBottomSheet(
        services: servicesList,
        availabilityData: availabilityData,
        onBookingConfirm: _onBookingConfirm,
      ),
    );
  }

  void _onBookingConfirm(
    List<Map<String, dynamic>> selectedServices,
    DateTime selectedDate,
    String selectedTimeSlot,
  ) {
    // Calculate total price
    double total = 0;
    for (var service in selectedServices) {
      final priceString = service['price'] as String? ?? '₹0';
      final price = double.tryParse(
              priceString.replaceAll('₹', '').replaceAll(',', '')) ??
          0;
      total += price;
    }

    // Show confirmation and navigate to booking flow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Booking confirmed for ${selectedDate.day}/${selectedDate.month} at $selectedTimeSlot - Total: ₹${total.toStringAsFixed(0)}',
        ),
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View Details',
          onPressed: () {
            Navigator.pushNamed(context, '/booking-flow-screen');
          },
        ),
      ),
    );
  }
}
