import 'package:flutter/material.dart';
import '../../services/freelancer_booking_api.dart';
import 'freelancer_job_detail_screen.dart';

class FreelancerJobFeedScreen extends StatefulWidget {
  const FreelancerJobFeedScreen({super.key});

  @override
  State<FreelancerJobFeedScreen> createState() => _FreelancerJobFeedScreenState();
}

class _FreelancerJobFeedScreenState extends State<FreelancerJobFeedScreen> {
  late Future<List<Map<String, dynamic>>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  void _loadJobs() {
    setState(() {
      _jobsFuture = FreelancerBookingApi().getFreelancerJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Jobs')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
             ));
          }
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
             return const Center(child: Text('No jobs assigned yet'));
          }

          return RefreshIndicator(
            onRefresh: () async => _loadJobs(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_,__) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _buildJobCard(context, job);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'UNKNOWN';
    final service = job['serviceCategory']?.toString().toUpperCase() ?? 'SERVICE';
    
    // Status Badge Logic
    Color badgeColor = Colors.grey;
    if (status == 'ASSIGNED') badgeColor = Colors.orange;
    else if (status == 'CONFIRMED') badgeColor = Colors.blue;
    else if (status == 'IN_PROGRESS') badgeColor = Colors.purple;
    else if (status == 'COMPLETED') badgeColor = Colors.green;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
           // Read-only detail view
           Navigator.push(context, MaterialPageRoute(builder: (_) => FreelancerJobDetailScreen(bookingId: job['bookingId'])));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(status, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                   const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                   const SizedBox(width: 4),
                   // Displaying raw timestamp/value if formatting util not available, usually requires intl
                   // For now, assume toString is safe enough for MVP or it's a formatted string from backend?
                   // Usually backend sends millis.
                   Expanded(child: Text('${job['scheduledAt'] ?? 'Date TBD'}', style: const TextStyle(color: Colors.grey), maxLines: 1)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Icon(Icons.location_on, size: 14, color: Colors.grey),
                   const SizedBox(width: 4),
                   Expanded(child: Text(job['location']?['address'] ?? 'No Address', style: const TextStyle(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
