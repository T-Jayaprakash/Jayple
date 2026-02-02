import 'package:flutter/material.dart';
import '../../services/booking_api.dart';
import 'booking_success_screen.dart';

class BookingCreateScreen extends StatefulWidget {
  final Map<String, dynamic> service;

  const BookingCreateScreen({super.key, required this.service});

  @override
  State<BookingCreateScreen> createState() => _BookingCreateScreenState();
}

class _BookingCreateScreenState extends State<BookingCreateScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submitBooking() async {
    if (_selectedDate == null || _selectedTime == null) return;

    setState(() => _isLoading = true);
    try {
      final scheduledAt = DateTime(
        _selectedDate!.year, 
        _selectedDate!.month, 
        _selectedDate!.day,
        _selectedTime!.hour, 
        _selectedTime!.minute,
      );

      await BookingApi().createBooking(
        serviceId: widget.service['id'],
        cityId: 'trichy', // Hardcoded city for B2.1 scope
        scheduledAt: scheduledAt,
        type: 'home', // Default
      );

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const BookingSuccessScreen())
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking Failed: $e'), 
            backgroundColor: Colors.red
          )
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Booking')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Service: ${widget.service['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 24),
             
             ListTile(
               title: Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
               trailing: const Icon(Icons.calendar_today),
               onTap: _isLoading ? null : _pickDate,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.grey)),
             ),
             const SizedBox(height: 16),
             ListTile(
               title: Text(_selectedTime == null ? 'Select Time' : _selectedTime!.format(context)),
               trailing: const Icon(Icons.access_time),
               onTap: _isLoading ? null : _pickTime,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.grey)),
             ),
             
             const Spacer(),
             
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                 onPressed: (_isLoading || _selectedDate == null || _selectedTime == null) ? null : _submitBooking,
                 child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Confirm Booking'),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
