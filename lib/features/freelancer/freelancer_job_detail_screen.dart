import 'package:flutter/material.dart';
import '../../services/freelancer_booking_api.dart';

class FreelancerJobDetailScreen extends StatefulWidget {
  final String bookingId;

  const FreelancerJobDetailScreen({super.key, required this.bookingId});

  @override
  State<FreelancerJobDetailScreen> createState() => _FreelancerJobDetailScreenState();
}

class _FreelancerJobDetailScreenState extends State<FreelancerJobDetailScreen> {
  int _refreshKey = 0;
  bool _isLoading = false;

  void _refresh() {
    if (mounted) setState(() => _refreshKey++);
  }

  Future<void> _handleAction(String action, String cityId) async {
    if (action == 'REJECT') {
       final confirm = await showDialog<bool>(
         context: context,
         builder: (ctx) => AlertDialog(
            title: const Text('Reject Job?'),
            content: const Text('Rejecting will pass this job to another freelancer. This cannot be undone.'),
            actions: [
               TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
               TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject', style: TextStyle(color: Colors.red))),
            ],
         )
       );
       if (confirm != true) return;
    }

    setState(() => _isLoading = true);
    try {
       await FreelancerBookingApi().respondToBooking(
         bookingId: widget.bookingId,
         cityId: cityId,
         action: action
       );
       if (!mounted) return;
       
       if (action == 'REJECT') {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job rejected.')));
       } else {
          _refresh(); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job accepted!'), backgroundColor: Colors.green));
       }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLifecycleAction(String type, String cityId) async {
      setState(() => _isLoading = true);
      try {
          if (type == 'START') {
              await FreelancerBookingApi().startJob(bookingId: widget.bookingId, cityId: cityId);
          } else if (type == 'COMPLETE') {
              await FreelancerBookingApi().completeJob(bookingId: widget.bookingId, cityId: cityId);
          }
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Job ${type.toLowerCase()}ed successfully!'), backgroundColor: Colors.green));
              _refresh();
          }
      } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      } finally {
         if (mounted) setState(() => _isLoading = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        key: ValueKey(_refreshKey), 
        future: FreelancerBookingApi().getJobDetail(widget.bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
             return const Center(child: Text('Job not found'));
          }

          final data = snapshot.data!;
          final status = data['status']?.toString();
          final type = data['type']?.toString();
          final cityId = data['cityId']?.toString() ?? 'trichy';

          // Show Accept/Reject buttons ONLY IF: type == "home" AND status == "ASSIGNED"
          final canRespond = (type == 'home' && status == 'ASSIGNED');

          return ListView(
             padding: const EdgeInsets.all(24),
             children: [
               _buildSectionHeader('Job Info'),
               _buildDetailRow('Service', data['serviceCategory']),
               _buildDetailRow('Status', status?.toUpperCase(), isStatus: true),
               _buildDetailRow('Time', '${data['scheduledAt']}'),
               _buildDetailRow('Booking ID', widget.bookingId),
               
               const Divider(height: 32),
               _buildSectionHeader('Location'),
               _buildDetailRow('Address', data['location']?['address'] ?? 'N/A'),
               
               const Divider(height: 32),
               _buildSectionHeader('Customer'),
               _buildDetailRow('Name', data['customerName'] ?? 'Guest'),
               
               const Divider(height: 32),
               _buildSectionHeader('Payment Details'),
               _buildDetailRow('Total Amount', '₹${data['totalAmount']}'),
               _buildDetailRow('Payment Status', data['paymentStatus']?.toString().toUpperCase() ?? 'PENDING'),
               
               const SizedBox(height: 48),

               if (canRespond) ...[
                 Row(
                   children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _handleAction('REJECT', cityId),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          child: const Text('Reject'),
                        )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleAction('ACCEPT', cityId),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          child: _isLoading 
                             ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                             : const Text('Accept Job'),
                        )
                      ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 const Text('Accepting this job commits you to visiting the customer location at the scheduled time.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
               
               ] else if (status == 'CONFIRMED') ...[
                 const SizedBox(height: 32),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 16)),
                     onPressed: _isLoading ? null : () => _handleLifecycleAction('START', cityId),
                     child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Start Job', style: TextStyle(color: Colors.white, fontSize: 16)),
                   )
                 ),

               ] else if (status == 'IN_PROGRESS') ...[ // Backend usually uses IN_PROGRESS or STARTED
                 const SizedBox(height: 32),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(vertical: 16)),
                     onPressed: _isLoading ? null : () => _handleLifecycleAction('COMPLETE', cityId),
                     child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Complete Job', style: TextStyle(color: Colors.white, fontSize: 16)),
                   )
                 ),

               ] else if (status == 'COMPLETED') ...[
                 const SizedBox(height: 32),
                 const Center(child: Chip(label: Text('Job Completed'), backgroundColor: Colors.blueAccent))
               
               ] else if (status == 'REJECTED') ...[
                 const SizedBox(height: 32),
                 Center(child: Chip(label: Text('Job Rejected', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red))
               ]
             ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent)),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500))),
           Expanded(child: Text(value?.toString() ?? '-', style: TextStyle(fontWeight: isStatus ? FontWeight.bold : FontWeight.w400, fontSize: 16, color: isStatus ? (value == 'ASSIGNED' ? Colors.orange : Colors.black) : null))),
        ],
      ),
    );
  }
}
