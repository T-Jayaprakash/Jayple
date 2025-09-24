import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/salon.dart';
import '../../models/user.dart' as user_model;
import '../../services/auth_service.dart';
import '../../services/salon_service.dart';
import './widgets/empty_state_widget.dart';
import './widgets/freelancer_card.dart';
import './widgets/location_header.dart';
import './widgets/quick_action_sheet.dart';
import './widgets/salon_card.dart';
// ...existing code...

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({Key? key}) : super(key: key);

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _currentLocation = "T. Nagar, Chennai";
  bool _isLoading = false;
  bool _hasLocationPermission = true;

  List<Salon> _nearbySalons = [];
  user_model.User? _currentUser;

  // Minimal mock freelancers data (optional, can be removed if not needed)
  final List<Map<String, dynamic>> _availableFreelancers = [
    {
      "id": 1,
      "name": "Rajesh Kumar",
      "profilePhoto":
          "https://images.pexels.com/photos/1043471/pexels-photo-1043471.jpeg?auto=compress&cs=tinysrgb&w=400",
      "services": ["Haircut", "Beard Styling"],
      "rating": 4.9,
      "reviewCount": 127,
      "isOnline": true,
      "phone": "+91 98765 43213"
    },
    {
      "id": 2,
      "name": "Priya Sharma",
      "profilePhoto":
          "https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=400",
      "services": ["Facial", "Manicure", "Pedicure"],
      "rating": 4.8,
      "reviewCount": 89,
      "isOnline": true,
      "phone": "+91 98765 43214"
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _checkLocationPermission();
    await _loadCurrentUser();
    await _loadSalons();
  }

  void _onScroll() {
    // No pagination in clean UI
  }

  Future<void> _checkLocationPermission() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _hasLocationPermission = true;
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = AuthService.instance.currentUser;
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Failed to load user: $error');
    }
  }

  Future<void> _loadSalons() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final salons = await SalonService.instance.getAllSalons(limit: 10);

      setState(() {
        _nearbySalons = salons;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load salons: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    await _loadSalons();
  }

  // No pagination in clean UI

  void _onLocationTap() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Change Location",
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'my_location',
                color: AppTheme.lightTheme.primaryColor,
                size: 24,
              ),
              title: const Text("Use Current Location"),
              onTap: () {
                Navigator.pop(context);
                _getCurrentLocation();
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'search',
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
              title: const Text("Search Location"),
              onTap: () {
                Navigator.pop(context);
                _searchLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate getting current location
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _currentLocation = "Anna Nagar, Chennai";
      _isLoading = false;
    });

    // Reload salons for new location
    await _loadSalons();
  }

  void _searchLocation() {
    // Navigate to location search screen
    Navigator.pushNamed(context, '/location-search');
  }

  void _onSearchChanged(String query) {
    if (query.isNotEmpty) {
      _searchSalons(query);
    } else {
      _loadSalons();
    }
  }

  Future<void> _searchSalons(String query) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final salons = await SalonService.instance.searchSalons(
        query: query,
        limit: 20,
      );

      setState(() {
        _nearbySalons = salons;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // No category selection in clean UI

  // No map view in clean UI

  void _onSalonTap(Salon salon) {
    Navigator.pushNamed(
      context,
      '/service-detail-screen',
      arguments: {
        'salon': salon,
        'type': 'salon',
      },
    );
  }

  void _onFreelancerTap(Map<String, dynamic> freelancer) {
    Navigator.pushNamed(
      context,
      '/service-detail-screen',
      arguments: {
        'freelancer': freelancer,
        'type': 'freelancer',
      },
    );
  }

  void _onLongPress(dynamic item) {
    HapticFeedback.mediumImpact();

    String name;
    String phone;

    if (item is Salon) {
      name = item.name;
      phone = item.ownerId ?? '';
    } else {
      name = item["name"] as String;
      phone = item["phone"] as String? ?? '';
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => QuickActionSheet(
        title: name,
        onSave: () {
          Navigator.pop(context);
          _saveItem(item);
        },
        onShare: () {
          Navigator.pop(context);
          _shareItem(item);
        },
        onCall: () {
          Navigator.pop(context);
          _callItem(phone);
        },
      ),
    );
  }

  void _saveItem(dynamic item) {
    final name = item is Salon ? item.name : item["name"];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$name saved to favorites")),
    );
  }

  void _shareItem(dynamic item) {
    final name = item is Salon ? item.name : item["name"];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Sharing $name")),
    );
  }

  void _callItem(String phone) {
    if (phone.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Calling $phone")),
      );
    }
  }

  void _onQuickBook() {
    if (_currentUser == null) {
      // Redirect to login
      Navigator.pushNamed(context, '/login-screen');
      return;
    }
    Navigator.pushNamed(context, '/booking-flow-screen');
  }

  void _enableLocation() {
    setState(() {
      _hasLocationPermission = true;
      _currentLocation = "T. Nagar, Chennai";
    });
    _loadSalons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: !_hasLocationPermission
            ? EmptyStateWidget(
                title: "Enable Location",
                subtitle:
                    "We need your location to show nearby salons and freelancers",
                buttonText: "Enable Location",
                onButtonPressed: _enableLocation,
              )
            : Column(
                children: [
                  LocationHeader(
                    currentLocation: _currentLocation,
                    onLocationTap: _onLocationTap,
                    searchController: _searchController,
                    onSearchChanged: _onSearchChanged,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshData,
                      child: _buildListView(),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home
              break;
            case 1:
              Navigator.pushNamed(context, '/bookings-screen');
              break;
            case 2:
              if (_currentUser == null) {
                Navigator.pushNamed(context, '/login-screen');
              } else {
                Navigator.pushNamed(context, '/profile-screen');
              }
              break;
            case 3:
              Navigator.pushNamed(context, '/more-screen');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'home',
              color: AppTheme.lightTheme.primaryColor,
              size: 24,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'calendar_today',
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'person',
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'more_horiz',
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onQuickBook,
        icon: CustomIconWidget(
          iconName: 'add',
          color: AppTheme.lightTheme.colorScheme.onPrimary,
          size: 24,
        ),
        label: Text(
          "Book Now",
          style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onPrimary,
          ),
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Jayple",
          style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.lightTheme.primaryColor,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/notifications-screen');
            },
            icon: CustomIconWidget(
              iconName: 'notifications',
              color: AppTheme.lightTheme.colorScheme.onSurface,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nearbySalons.isEmpty && _availableFreelancers.isEmpty) {
      return EmptyStateWidget(
        title: "No Services Nearby",
        subtitle: "Try changing your location or expanding your search radius",
        buttonText: "Change Location",
        onButtonPressed: _onLocationTap,
      );
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      children: [
        if (_nearbySalons.isNotEmpty) ...[
          Text(
            "Nearby Salons",
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          ..._nearbySalons
              .map((salon) => SalonCard(
                    salon: salon,
                    onTap: () => _onSalonTap(salon),
                    onLongPress: () => _onLongPress(salon),
                  ))
              .toList(),
        ],
        if (_availableFreelancers.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            "Available Freelancers",
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          ..._availableFreelancers
              .map((freelancer) => FreelancerCard(
                    freelancer: freelancer,
                    onTap: () => _onFreelancerTap(freelancer),
                    onLongPress: () => _onLongPress(freelancer),
                  ))
              .toList(),
        ],
        SizedBox(height: 10.h), // Space for FAB
      ],
    );
  }

  // No map view in clean UI
}
