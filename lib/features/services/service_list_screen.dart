import 'package:flutter/material.dart';
import '../../services/booking_api.dart';
import 'service_detail_screen.dart';

class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = BookingApi.mockServices;

    return Scaffold(
      appBar: AppBar(title: const Text('Browse Services')),
      body: ListView.separated(
        itemCount: services.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final service = services[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${service['duration']} mins • ₹${service['price']}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: service)),
              );
            },
          );
        },
      ),
    );
  }
}
