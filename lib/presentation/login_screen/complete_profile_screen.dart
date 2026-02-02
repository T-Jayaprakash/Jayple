import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'location_picker_screen.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart' as user_model;

class CompleteProfileScreen extends StatefulWidget {
  final String phone;
  const CompleteProfileScreen({Key? key, required this.phone})
      : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  Future<void> _pickLocationOnMap() async {
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          onLocationPicked: (address, lat, lng) {
            setState(() {
              _locationController.text = address;
            });
          },
        ),
      ),
    );
  }

  Future<void> _detectLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String address = [
          place.name,
          place.locality,
          place.administrativeArea,
          place.country
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        _locationController.text = address;
      } else {
        throw Exception('Unable to get address');
      }
    } catch (e) {
      // No-op: console messages/snackbars removed as per request
    } finally {
      setState(() => _isLoading = false);
    }
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = user_model.User(
        id: AuthService.instance.currentUser!.uid,
        phone: widget.phone,
        fullName: _nameController.text.trim(),
        role: 'customer', // Default, should probably pass from signup flow
        createdAt: DateTime.now(),
      );
      await AuthService.instance.createOrUpdateUserProfile(user);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/customer-home-screen');
      }
    } catch (e) {
      // No-op: console messages/snackbars removed as per request
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name', style: Theme.of(context).textTheme.bodyLarge),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Enter your name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 24),
              Text('Location', style: Theme.of(context).textTheme.bodyLarge),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                          hintText: 'Enter your location'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Location required'
                          : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Detect my location',
                    onPressed: _isLoading ? null : _detectLocation,
                  ),
                  IconButton(
                    icon: const Icon(Icons.map),
                    tooltip: 'Pick from map',
                    onPressed: _isLoading ? null : _pickLocationOnMap,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save & Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
