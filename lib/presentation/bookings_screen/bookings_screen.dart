import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({Key? key}) : super(key: key);

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final BookingService _bookingService = BookingService.instance;
  List<Booking> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final bookings = await _bookingService.getUserBookings();
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Failed to load bookings: $e"))
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch(status) {
      case 'confirmed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty 
             ? const Center(child: Text("No bookings found"))
             : RefreshIndicator(
                 onRefresh: _loadBookings,
                 child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final booking = _bookings[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                             booking.salonId ?? "Service", 
                             style: const TextStyle(fontWeight: FontWeight.bold)
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text("Date: ${DateFormat.yMMMd().format(booking.startAt)}"),
                              Text("Time: ${DateFormat.jm().format(booking.startAt)}"),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(booking.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _getStatusColor(booking.status))
                                ),
                                child: Text(
                                  booking.status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(booking.status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                 ),
             ),
    );
  }
}
