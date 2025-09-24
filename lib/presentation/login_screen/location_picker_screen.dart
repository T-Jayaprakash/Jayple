import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerScreen extends StatefulWidget {
  final Function(String address, double lat, double lng) onLocationPicked;
  const LocationPickerScreen({Key? key, required this.onLocationPicked})
      : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedLatLng;
  String? _pickedAddress;
  bool _isLoading = false;

  void _onMapTap(LatLng latLng) async {
    setState(() {
      _pickedLatLng = latLng;
      _isLoading = true;
    });
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String address = [
          place.name,
          place.locality,
          place.administrativeArea,
          place.country
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() {
          _pickedAddress = address;
        });
      }
    } catch (e) {
      setState(() {
        _pickedAddress = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location on Map')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(13.0827, 80.2707), // Default to Chennai
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            markers: _pickedLatLng == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLatLng!,
                    ),
                  },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_pickedAddress != null && !_isLoading)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_pickedAddress!,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          widget.onLocationPicked(
                            _pickedAddress!,
                            _pickedLatLng!.latitude,
                            _pickedLatLng!.longitude,
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Use this location'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
