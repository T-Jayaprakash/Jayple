import 'package:flutter/material.dart';
import '../booking/booking_create_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(service['name'])),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service['category'].toString().toUpperCase(), 
              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Text(service['name'], style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text('Price: ₹${service['price']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            Text('Duration: ${service['duration']} mins', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            Text(service['description'] ?? 'No description available.', style: const TextStyle(fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingCreateScreen(service: service),
                    ),
                  );
                },
                child: const Text('Book Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
