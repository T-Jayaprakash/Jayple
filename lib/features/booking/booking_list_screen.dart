import 'package:flutter/material.dart';
import '../../services/booking_api.dart';
import 'booking_detail_screen.dart';

class BookingListScreen extends StatelessWidget {
  const BookingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: BookingApi().getMyBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
             ));
          }
          
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
             return const Center(child: Text('No bookings found.'));
          }

          return ListView.separated(
            itemCount: bookings.length,
            separatorBuilder: (_,__) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final b = bookings[index];
              final rawDate = b['scheduledAt'];
              // Determine display date (Timestamp or millis)
              String dateStr = 'Unknown Date';
              // Cloud Functions usually return Timestamps as Map {_seconds, _nanoseconds} or millis.
              // We'll simplisticly show status for now or parse if possible.
              // B2.1 Requirement: "Shows status, service name, scheduled time"
              
              return ListTile(
                title: Text(b['serviceCategory']?.toString().toUpperCase() ?? 'SERVICE', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${b['status']}'),
                    // Text('ID: ${b['bookingId']}'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b['bookingId'] ?? '')));
                },
              );
            },
          );
        },
      ),
    );
  }
}
