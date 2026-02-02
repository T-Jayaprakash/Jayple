import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/salon_service.dart';
import '../../models/salon.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({Key? key}) : super(key: key);

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  final SalonService _salonService = SalonService.instance;
  final AuthService _authService = AuthService.instance;
  List<Salon> _mySalons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMySalons();
  }

  Future<void> _loadMySalons() async {
    setState(() => _isLoading = true);
    final user = _authService.currentUser;
    if (user != null) {
      final salons = await _salonService.getSalonsByOwner(user.uid);
      if (mounted) {
        setState(() {
          _mySalons = salons;
          _isLoading = false;
        });
      }
    } else {
        setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewSalon() async {
     // TODO: Implement full Create Salon form
     // For now, create a dummy one for testing
     try {
       await _salonService.createSalon(
           name: "My New Salon ${DateTime.now().second}",
           address: "123 Test St",
           description: "A test salon created by vendor",
           openTime: "09:00:00",
           closeTime: "20:00:00"
       );
       _loadMySalons();
     } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMySalons,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
               await _authService.signOut();
               if(mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _mySalons.isEmpty 
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          const Text("You haven't added any salons yet."),
                          const SizedBox(height: 20),
                          ElevatedButton(
                              onPressed: _createNewSalon, 
                              child: const Text("Create First Salon")
                          )
                      ]
                  )
              )
              : ListView.builder(
                  itemCount: _mySalons.length,
                  itemBuilder: (context, index) {
                      final salon = _mySalons[index];
                      return ListTile(
                          title: Text(salon.name),
                          subtitle: Text(salon.address ?? 'No address'),
                          trailing: const Icon(Icons.chevron_right),
                      );
                  },
              ),
      floatingActionButton: _mySalons.isNotEmpty 
          ? FloatingActionButton(
              onPressed: _createNewSalon,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
