import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/vendor_booking_api.dart';

class VendorEarningsScreen extends StatefulWidget {
  const VendorEarningsScreen({super.key});

  @override
  State<VendorEarningsScreen> createState() => _VendorEarningsScreenState();
}

class _VendorEarningsScreenState extends State<VendorEarningsScreen> {
  late Future<Map<String, dynamic>> _earningsFuture;

  @override
  void initState() {
    super.initState();
    _earningsFuture = VendorBookingApi().getVendorEarnings();
  }

  Future<void> _refresh() async {
    setState(() {
      _earningsFuture = VendorBookingApi().getVendorEarnings();
    });
    await _earningsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _earningsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text('Failed to load earnings.\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
             ));
          }
          
          final data = snapshot.data ?? {};
          final num totalEarnings = data['totalEarnings'] ?? 0;
          final num totalCommission = data['totalCommission'] ?? 0;
          final num netPayable = data['netPayable'] ?? 0;
          final num outstandingBalance = data['outstandingBalance'] ?? 0;
          final lastSettlement = data['lastSettlementAt']; // Timestamp or string? Usually formatted by UI
          
          // Assuming transactions list
          final List transactions = data['recentTransactions'] ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSummaryCard(totalEarnings, totalCommission, netPayable, outstandingBalance),
                const SizedBox(height: 24),
                if (lastSettlement != null)
                   Padding(
                     padding: const EdgeInsets.only(bottom: 16.0),
                     child: Text('Last Settlement: $lastSettlement', style: const TextStyle(color: Colors.grey)), // TODO: Format better if timestamp is object
                   ),
                
                Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                
                if (transactions.isEmpty)
                   const Padding(
                     padding: EdgeInsets.all(24.0),
                     child: Center(child: Text('No recent transactions.')),
                   )
                else
                   ...transactions.map((tx) => _buildTransactionTile(tx)).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(num total, num commission, num net, num outstanding) {
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
                 _buildStat('Total Earnings', total, Colors.black),
                 _buildStat('Commission', commission, Colors.red[700]!),
               ],
             ),
             const Divider(height: 32),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 _buildStat('Net Payable', net, Colors.green[700]!),
                 _buildStat('Outstanding', outstanding, Colors.orange[800]!),
               ],
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, num amount, Color color) {
    final currency = NumberFormat.simpleCurrency(name: 'INR'); // Using INR as context implies India (Trichy)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(currency.format(amount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final type = tx['type'] ?? 'UNKNOWN';
    final amount = tx['amount'] ?? 0;
    final isCredit = (type == 'EARNING' || type == 'REFUND'); // Logic depends on backend, assuming Earning is +
    final color = isCredit ? Colors.green : Colors.red;
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 16),
      ),
      title: Text(type.toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(tx['bookingId']?.toString() ?? '-'), // Show Booking ID
      trailing: Text(
        '${isCredit ? '+' : '-'} ₹$amount', 
        style: TextStyle(color: color, fontWeight: FontWeight.bold)
      ),
    );
  }
}
