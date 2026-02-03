import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import 'freelancer_job_feed_screen.dart';
import 'freelancer_earnings_screen.dart';

class FreelancerHome extends StatelessWidget {
  const FreelancerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freelancer Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Icon(Icons.assignment_ind, size: 64, color: Colors.blue),
             const SizedBox(height: 24),
             const Text('Welcome Freelancer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
             const SizedBox(height: 16),
             const Text('Access your assigned jobs and schedule.', style: TextStyle(color: Colors.grey)),
             const SizedBox(height: 48),
             ElevatedButton.icon(
                icon: const Icon(Icons.work_outline),
                label: const Text('View My Jobs'),
                style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                   textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                   Navigator.push(
                     context, 
                     MaterialPageRoute(builder: (_) => const FreelancerJobFeedScreen())
                   );
                },
             ),
             const SizedBox(height: 16),
             ElevatedButton.icon(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('My Earnings'),
                style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
                   backgroundColor: Colors.white,
                   foregroundColor: Colors.blueGrey,
                   side: const BorderSide(color: Colors.grey),
                   textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                   Navigator.push(
                     context, 
                     MaterialPageRoute(builder: (_) => const FreelancerEarningsScreen())
                   );
                },
             ),
          ],
        ),
      ),
    );
  }
}
