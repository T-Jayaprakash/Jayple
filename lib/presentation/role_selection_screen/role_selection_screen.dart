import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  Future<void> _selectRole(BuildContext context, String role) async {
    // Save role to Firestore
    final authService = AuthService();
    final user = authService.currentUser;
    if (user != null) {
      await authService.createUserProfile(user.uid, role, user.phoneNumber ?? '');
      
      // Navigate to respective home
      String route;
      switch (role) {
        case 'vendor':
          route = AppRoutes.vendorHome;
          break;
        case 'freelancer':
          route = AppRoutes.freelancerHome;
          break;
        case 'customer':
        default:
          route = AppRoutes.customerHome;
          break;
      }
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Role')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Who are you?',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _selectRole(context, 'customer'),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Customer'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _selectRole(context, 'vendor'),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Vendor'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _selectRole(context, 'freelancer'),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Freelancer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
