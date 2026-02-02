import 'package:flutter/material.dart';
import '../../services/booking_api.dart';
import '../../features/payment/payment_status_widget.dart';
import 'booking_cancel_dialog.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  int _refreshKey = 0;

  void _refresh() {
    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        key: ValueKey(_refreshKey), // Force re-fetch on refresh
        future: BookingApi().getBookingById(widget.bookingId),
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
          if (!snapshot.hasData || snapshot.data == null) {
             return const Center(child: Text('Booking not found.'));
          }

          final data = snapshot.data!;
          final status = data['status'] as String?;
          
          return RefreshIndicator(
            onRefresh: () async {
                _refresh();
                await BookingApi().getBookingById(widget.bookingId);
            },
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                 Text('Booking Information', style: Theme.of(context).textTheme.headlineSmall),
                 const SizedBox(height: 16),
                 _buildDetailRow('Status', status?.toUpperCase(), isStatus: true),
                 const Divider(height: 32),
                 _buildDetailRow('Service Category', data['serviceCategory']),
                 _buildDetailRow('Service Type', data['serviceType']),
                 _buildDetailRow('Amount', '₹${data['totalAmount']}'),
                 _buildDetailRow('Location', data['location']?['address']),
                 const Divider(height: 16),
                 
                 // Payment Integration
                 PaymentStatusWidget(
                     booking: data,
                     onPaymentSuccess: _refresh,
                 ),

                 // Cancellation Integration (B2.3)
                 // Show only if status allows cancellation/refund request
                 if (['CREATED', 'CONFIRMED', 'COMPLETED'].contains(status)) ...[
                   const SizedBox(height: 48),
                   SizedBox(
                     width: double.infinity,
                     child: OutlinedButton.icon(
                       icon: const Icon(Icons.cancel_outlined),
                       label: const Text('Cancel Booking'),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.red,
                         side: const BorderSide(color: Colors.red),
                         padding: const EdgeInsets.symmetric(vertical: 16),
                       ),
                       onPressed: () {
                         showDialog(
                           context: context,
                           builder: (_) => BookingCancelDialog(
                             bookingId: widget.bookingId,
                             onCancelled: _refresh,
                           ),
                         );
                       },
                     ),
                   ),
                 ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            SizedBox(
                width: 120, 
                child: Text(
                    label, 
                    style: TextStyle(
                        fontWeight: FontWeight.w600, 
                        color: Colors.grey[700]
                    )
                )
            ),
            Expanded(
                child: Text(
                    value?.toString() ?? '-',
                    style: TextStyle(
                        fontWeight: isStatus ? FontWeight.bold : FontWeight.normal,
                        color: isStatus ? Colors.blue : null,
                        fontSize: isStatus ? 16 : 14,
                    )
                )
            ),
        ],
      ),
    );
  }
}
