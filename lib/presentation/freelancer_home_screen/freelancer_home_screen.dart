import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';

class FreelancerHomeScreen extends StatelessWidget {
  const FreelancerHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freelancer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
               await AuthService.instance.signOut();
               if (context.mounted) {
                   Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
               }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome Freelancer!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            const Text('Your gigs and tasks will appear here.'),
          ],
        ),
      ),
    );
  }
}
