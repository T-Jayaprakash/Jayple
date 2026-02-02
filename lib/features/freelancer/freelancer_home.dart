import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';

class FreelancerHome extends StatelessWidget {
  const FreelancerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freelancer Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: const Center(child: Text('Welcome Freelancer')),
    );
  }
}
