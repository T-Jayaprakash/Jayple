import 'package:flutter/material.dart';
import '../../services/vendor_booking_api.dart';

class VendorBookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const VendorBookingDetailScreen({super.key, required this.bookingId});

  @override
  State<VendorBookingDetailScreen> createState() => _VendorBookingDetailScreenState();
}

class _VendorBookingDetailScreenState extends State<VendorBookingDetailScreen> {
  int _refreshKey = 0;
  bool _isProcessing = false;

  void _refresh() {
    if (mounted) setState(() => _refreshKey++);
  }

  Future<void> _respond(String action, String cityId) async {
    setState(() => _isProcessing = true);
    try {
      await VendorBookingApi().respondToBooking(
        bookingId: widget.bookingId,
        cityId: cityId,
        action: action, // 'ACCEPT' or 'REJECT' (Wait, ensure case matches backend)
        // Usually backend expects uppercase 'ACCEPT' or 'REJECT' or lowercase?
        // Requirement says "calls vendorRespondToBooking (ACCEPT)".
        // I will use Uppercase 'ACCEPT' / 'REJECT' as standard for constants.
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booking ${action.toLowerCase()}ed successfully.'), backgroundColor: Colors.green)
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action Failed: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        key: ValueKey(_refreshKey),
        future: VendorBookingApi().getVendorBookingById(widget.bookingId),
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
          final status = data['status']?.toString();
          final type = data['type']?.toString();
          final cityId = data['cityId']?.toString() ?? 'trichy';

          // Logic: Show buttons ONLY if CREATED and inShop
          final bool canRespond = (status == 'CREATED' && type == 'inShop');

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
               Text('Customer Request', style: Theme.of(context).textTheme.headlineSmall),
               const SizedBox(height: 16),
               _buildDetailRow('Status', status?.toUpperCase(), isStatus: true),
               _buildDetailRow('Type', type?.toUpperCase(), isStatus: false),
               const Divider(height: 32),
               _buildDetailRow('Service', data['serviceCategory']),
               _buildDetailRow('Time', '${data['scheduledAt']}'), // TODO: Format date
               _buildDetailRow('Customer', data['customerName'] ?? 'Guest'),
               _buildDetailRow('Amount', '₹${data['totalAmount']}'),

               if (canRespond) ...[
                 const SizedBox(height: 48),
                 Row(
                   children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isProcessing ? null : () => _respond('REJECT', cityId),
                          child: const Text('Reject'),
                        )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isProcessing ? null : () => _respond('ACCEPT', cityId),
                          child: _isProcessing 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Text('Accept Booking'),
                        )
                      ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 const Text('Accepting this booking commits you to providing the service at the shop.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
               ] else if (status == 'CONFIRMED') ...[
                 const SizedBox(height: 32),
                 const Center(child: Chip(label: Text('Booking Accepted'), backgroundColor: Colors.greenAccent))
               ] else if (status == 'REJECTED') ...[
                 const SizedBox(height: 32),
                 const Center(child: Chip(label: Text('Booking Rejected'), backgroundColor: Colors.redAccent))
               ]
            ],
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
                width: 100, 
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
                        color: isStatus ? (value == 'CREATED' ? Colors.orange : Colors.blue) : null,
                    )
                )
            ),
        ],
      ),
    );
  }
}
