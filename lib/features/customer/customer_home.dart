import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../services/service_list_screen.dart';
import '../booking/booking_list_screen.dart';

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jayple'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My Bookings',
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const BookingListScreen())
              );
            },
          ),
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
                 const Icon(Icons.storefront, size: 64, color: Colors.blue),
                 const SizedBox(height: 24),
                 const Text(
                     'Welcome to Jayple',
                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                 ),
                 const SizedBox(height: 16),
                 const Padding(
                   padding: EdgeInsets.symmetric(horizontal: 32.0),
                   child: Text(
                     'Find and book services near you.',
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Colors.grey),
                   ),
                 ),
                 const SizedBox(height: 48),
                 ElevatedButton.icon(
                     icon: const Icon(Icons.search),
                     label: const Text('Browse Services'),
                     style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                         textStyle: const TextStyle(fontSize: 18),
                     ),
                     onPressed: () {
                         Navigator.push(
                             context, 
                             MaterialPageRoute(builder: (_) => const ServiceListScreen())
                         );
                     },
                 )
            ],
        ),
      ),
    );
  }
}
