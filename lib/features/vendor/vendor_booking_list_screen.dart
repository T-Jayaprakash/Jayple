import 'package:flutter/material.dart';
import '../../services/vendor_booking_api.dart';
import 'vendor_booking_detail_screen.dart';

class VendorBookingListScreen extends StatefulWidget {
  const VendorBookingListScreen({super.key});

  @override
  State<VendorBookingListScreen> createState() => _VendorBookingListScreenState();
}

class _VendorBookingListScreenState extends State<VendorBookingListScreen> {
  // Add refresh capability
  Future<List<Map<String, dynamic>>>? _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    setState(() {
      _bookingsFuture = VendorBookingApi().getVendorBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Bookings')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
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

          return RefreshIndicator(
            onRefresh: () async { _loadBookings(); },
            child: ListView.separated(
              itemCount: bookings.length,
              separatorBuilder: (_,__) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final b = bookings[index];
                final status = b['status']?.toString() ?? 'UNKNOWN';
                
                // Identify priority items
                final bool isActionRequired = (status == 'CREATED' || status == 'ASSIGNED');
                final bool isLive = (status == 'CONFIRMED' || status == 'IN_PROGRESS');
                final bool isDisabled = (status == 'CANCELLED' || status == 'FAILED');
                // Note: "CANCELLED / FAILED -> Disabled" in Prompt Requirements

                return ListTile(
                  enabled: !isDisabled,
                  title: Text(
                      b['serviceCategory']?.toString().toUpperCase() ?? 'SERVICE', 
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDisabled ? Colors.grey : null,
                      )
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $status', style: TextStyle(color: isActionRequired ? Colors.orange : (isLive ? Colors.blue : null))),
                      // Show date if possible, assuming raw map or proper handling
                      Text('Customer: ${b['customerName'] ?? 'Guest'}'),
                    ],
                  ),
                  trailing: isActionRequired 
                      ? const Chip(
                          label: Text('Action Required', style: TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: Colors.redAccent,
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                     // Even disabled items usually allow viewing details for history?
                     // Prompt says "Disabled". I'll disable navigation or just visual style?
                     // "Tap -> navigate to Booking Detail"
                     // "CANCELLED / FAILED -> Disabled" usually implies functionality.
                     // But history is important. I'll allow Tap but keep visual disabled style.
                     // Requirement: "Disabled" - I will interpret as interactive but grayed out, or strictly non-interactive?
                     // "Tap -> navigate to Booking Detail" is a general rule.
                     Navigator.push(context, MaterialPageRoute(builder: (_) => VendorBookingDetailScreen(bookingId: b['bookingId'])));
                  }.call, // Using .call to allow null if I wanted strict disable
                );
              },
            ),
          );
        },
      ),
    );
  }
}
