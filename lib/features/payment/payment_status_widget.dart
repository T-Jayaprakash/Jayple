import 'package:flutter/material.dart';
import '../../services/booking_api.dart';

class PaymentStatusWidget extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onPaymentSuccess;

  const PaymentStatusWidget({
    super.key,
    required this.booking,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentStatusWidget> createState() => _PaymentStatusWidgetState();
}

class _PaymentStatusWidgetState extends State<PaymentStatusWidget> {
  bool _isLoading = false;

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);
    
    try {
      final bookingId = widget.booking['bookingId'];
      await BookingApi().authorizePayment(bookingId);
      
      // Notify parent to refresh data
      widget.onPaymentSuccess();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Authorized Successfully!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.booking.containsKey('payment') || widget.booking['payment'] == null) {
      return const SizedBox.shrink(); // No payment info
    }

    final payment = widget.booking['payment'] as Map<String, dynamic>;
    final mode = payment['mode'] ?? 'UNKNOWN';
    final status = payment['status'] ?? 'UNKNOWN';

    final bool isOnlinePending = (mode == 'ONLINE' && status == 'PENDING');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mode: $mode', style: TextStyle(color: Colors.grey[700])),
                _buildStatusChip(status),
              ],
            ),
            if (isOnlinePending) ...[
              const SizedBox(height: 16),
              const Text('Payment is pending. Please complete the payment to confirm your booking.', 
                  style: TextStyle(fontSize: 12, color: Colors.orange)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading ? null : _processPayment,
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('Pay Now'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'CAPTURED':
      case 'SUCCESS': // Mapping possible statuses
        color = Colors.green;
        break;
      case 'PENDING':
      case 'AUTHORIZED':
        color = Colors.orange;
        break;
      case 'FAILED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
