import 'package:flutter/material.dart';
import '../../services/freelancer_earnings_api.dart';

class FreelancerEarningsScreen extends StatefulWidget {
  const FreelancerEarningsScreen({super.key});

  @override
  State<FreelancerEarningsScreen> createState() => _FreelancerEarningsScreenState();
}

class _FreelancerEarningsScreenState extends State<FreelancerEarningsScreen> {
  late Future<Map<String, dynamic>> _earningsFuture;

  @override
  void initState() {
    super.initState();
    _earningsFuture = FreelancerEarningsApi().getEarnings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Earnings')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _earningsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text('Error loading earnings.\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
             ));
          }
          
          final data = snapshot.data ?? {};
          final List transactions = data['transactions'] ?? []; // Adjust key based on Cloud Function response shape, usually 'recentTransactions' or 'ledger'
          final num totalEarnings = data['totalEarnings'] ?? 0; // Adjust key
          
          // Assuming backend returns a summary object
          // If structure differs, we adapt. Based on B3.3 "getVendorEarningsSummary" returns:
          // totalEarnings, totalCommission, netPayable, outstandingBalance, recentTransactions
          // I will assume same shape for Freelancer or generic 'getMyEarnings'.

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _earningsFuture = FreelancerEarningsApi().getEarnings();
              });
              await _earningsFuture;
            },
            child: ListView(
               padding: const EdgeInsets.all(16),
               children: [
                  _buildSummaryCard(data),
                  const SizedBox(height: 24),
                  Text('Recent History', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (transactions.isEmpty)
                     const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No earnings found.'))),
                  
                  ...transactions.map((tx) => _buildTransactionRow(tx)),
               ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
     final total = data['netPayable'] ?? data['totalEarnings'] ?? 0; // Net is strict for freelancers usually
     final outstanding = data['outstandingBalance'] ?? 0;

     return Card(
       elevation: 4,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       child: Padding(
         padding: const EdgeInsets.all(20.0),
         child: Column(
           children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildStat('Net Payable', total, Colors.green[700]!),
                   _buildStat('Outstanding', outstanding, Colors.red[700]!),
                ],
              ),
           ],
         ),
       ),
     );
  }

  Widget _buildStat(String label, num amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text('₹$amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: color)),
      ],
    );
  }

  Widget _buildTransactionRow(dynamic txData) {
    final Map<String, dynamic> tx = Map<String, dynamic>.from(txData as Map);
    final type = tx['type']?.toString().toUpperCase() ?? 'UNKNOWN';
    final amount = tx['amount'] ?? 0;
    final bookingId = tx['bookingId']?.toString() ?? '-';
    
    // Logic: Earning is Credit (+), Commission/Penalty is Debit (-)
    final isCredit = type == 'EARNING' || type == 'REFUND'; // Usually, refund might be debit depending on direction. 
    // Checking B3.3: type == "EARNING" | "COMMISSION" | "REFUND"
    final color = (type == 'EARNING') ? Colors.green : Colors.red;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[300]!)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(type == 'EARNING' ? Icons.add : Icons.remove, color: color, size: 16),
        ),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('Booking: $bookingId'),
        trailing: Text(
          '${type == 'EARNING' ? '+' : '-'} ₹$amount', 
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)
        ),
      ),
    );
  }
}
