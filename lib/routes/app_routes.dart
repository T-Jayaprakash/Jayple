import 'package:flutter/material.dart';
import '../presentation/customer_home_screen/customer_home_screen.dart';
import '../presentation/booking_flow_screen/booking_flow_screen.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/service_detail_screen/service_detail_screen.dart';
import '../presentation/login_screen/login_screen.dart';
import '../presentation/onboarding_flow/onboarding_flow.dart';
import '../presentation/customer_home_screen/customer_profile_screen.dart';
import '../presentation/vendor_home_screen/vendor_home_screen.dart';
import '../presentation/freelancer_home_screen/freelancer_home_screen.dart';
import '../presentation/role_selection_screen/role_selection_screen.dart';
import '../presentation/bookings_screen/bookings_screen.dart';
import '../presentation/placeholders.dart';

class AppRoutes {
  static const String profile = '/profile-screen';
  static const String initial = '/';
  static const String customerHome = '/customer-home-screen';
  static const String vendorHome = '/vendor-home-screen';
  static const String freelancerHome = '/freelancer-home-screen';
  static const String roleSelection = '/role-selection-screen';
  static const String bookingFlow = '/booking-flow-screen';
  static const String splash = '/splash-screen';
  static const String serviceDetail = '/service-detail-screen';
  static const String login = '/login-screen';
  static const String onboardingFlow = '/onboarding-flow';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    customerHome: (context) => const CustomerHomeScreen(),
    vendorHome: (context) => const VendorHomeScreen(),
    freelancerHome: (context) => const FreelancerHomeScreen(),
    roleSelection: (context) => const RoleSelectionScreen(),
    bookingFlow: (context) => const BookingFlowScreen(),
    splash: (context) => const SplashScreen(),
    serviceDetail: (context) => const ServiceDetailScreen(),
    login: (context) => const LoginScreen(),
    onboardingFlow: (context) => const OnboardingFlow(),
    profile: (context) => const CustomerProfileScreen(),
    '/bookings-screen': (context) => const BookingsScreen(),
    '/more-screen': (context) => const PlaceholderScreen(title: "More"),
    '/notifications-screen': (context) => const PlaceholderScreen(title: "Notifications"),
    '/location-search': (context) => const PlaceholderScreen(title: "Search Location"),
  };
}
