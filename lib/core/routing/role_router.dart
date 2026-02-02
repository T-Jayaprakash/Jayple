import 'package:flutter/material.dart';
import '../auth/user_model.dart';
import '../../features/customer/customer_home.dart';
import '../../features/vendor/vendor_home.dart';
import '../../features/freelancer/freelancer_home.dart';

class RoleRouter extends StatelessWidget {
  final AppUser user;

  const RoleRouter({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    switch (user.activeRole) {
      case 'customer':
        return const CustomerHome();
      case 'vendor':
        return const VendorHome();
      case 'freelancer':
        return const FreelancerHome();
      default:
        // Fail fast on invalid role
        return Scaffold(
          body: Center(
            child: Text(
              'Fatal Error: Unknown role "${user.activeRole}"',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
    }
  }
}
