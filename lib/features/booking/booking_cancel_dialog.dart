import 'package:flutter/material.dart';
import '../../services/booking_api.dart';

class BookingCancelDialog extends StatefulWidget {
  final String bookingId;
  final VoidCallback onCancelled;

  const BookingCancelDialog({
    super.key, 
    required this.bookingId, 
    required this.onCancelled
  });

  @override
  State<BookingCancelDialog> createState() => _BookingCancelDialogState();
}

class _BookingCancelDialogState extends State<BookingCancelDialog> {
  bool _isLoading = false;

  Future<void> _cancel() async {
    setState(() => _isLoading = true);
    try {
      await BookingApi().cancelBooking(widget.bookingId);
      
      // Notify parent to refresh
      widget.onCancelled();
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully.'))
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog on error usually, or let retry?
        // Prompt says "Handle backend errors explicitly".
        // Better to close dialog and show SnackBar contextually on screen.
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cancellation Failed: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('Cancel Booking?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel this booking?'),
            SizedBox(height: 12),
            Text(
                'Note: Cancellation is subject to backend verification. '
                'Penalties may apply based on the cancellation policy.',
                style: TextStyle(fontSize: 12, color: Colors.grey)
            ),
          ],
        ),
        actions: [
            TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text('Dismiss'),
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, 
                    foregroundColor: Colors.white
                ),
                onPressed: _isLoading ? null : _cancel,
                child: _isLoading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Confirm Cancel'),
            )
        ],
    );
  }
}
