import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import 'vendor_booking_list_screen.dart';
import 'vendor_earnings_screen.dart';

class VendorHome extends StatelessWidget {
  const VendorHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
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
            const Icon(Icons.store, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            const Text('Welcome Vendor', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Manage your shop bookings from here.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              icon: const Icon(Icons.inbox),
              label: const Text('Booking Inbox'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const VendorBookingListScreen())
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('My Earnings'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 16),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueGrey,
                  side: const BorderSide(color: Colors.grey),
                  textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VendorEarningsScreen())
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
