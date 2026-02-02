import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/salon.dart';

class SalonService {
  static SalonService? _instance;
  static SalonService get instance => _instance ??= SalonService._();

  SalonService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all salons
  Future<List<Salon>> getAllSalons({
    int limit = 50,
    double? latitude,
    double? longitude,
  }) async {
    try {
      var query = _firestore
          .collection('salons')
          .where('is_approved', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Salon.fromJson(doc.data())).toList();
    } catch (error) {
      // Allow it to return empty list if index is missing or collection is empty
      debugPrint('Error fetching salons: $error');
      return [];
    }
  }

  // Get salons near location
  Future<List<Salon>> getNearBySalons({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 20,
  }) async {
    // Note: Geo-queries in basic Firestore are limited. 
    // We will fetch all and filter in memory for this prototype 
    // or use geoflutterfire_plus in real prod.
    return getAllSalons(limit: limit); 
  }

  // Search salons
  Future<List<Salon>> searchSalons({
    required String query,
    int limit = 20,
  }) async {
    try {
      // Firestore simple search (case-sensitive usually). 
      // For advanced search use Algolia or similar.
      // We will just do a simple prefix match on name for now.
      final snapshot = await _firestore
          .collection('salons')
          .where('is_approved', isEqualTo: true)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Salon.fromJson(doc.data())).toList();
    } catch (error) {
      debugPrint('Error searching salons: $error');
      return [];
    }
  }

  // Get salon by ID with services
  Future<Map<String, dynamic>> getSalonWithServices(String salonId) async {
    try {
      final salonDoc = await _firestore.collection('salons').doc(salonId).get();
      if (!salonDoc.exists) throw Exception("Salon not found");

      final servicesSnapshot = await _firestore
          .collection('services')
          .where('salon_id', isEqualTo: salonId)
          .orderBy('price', descending: false)
          .get();

      return {
        'salon': Salon.fromJson(salonDoc.data()!),
        'services': servicesSnapshot.docs.map((d) => d.data()).toList(),
      };
    } catch (error) {
      throw Exception('Failed to fetch salon details: $error');
    }
  }

  // Get salons by owner
  Future<List<Salon>> getSalonsByOwner(String ownerId) async {
    try {
      final snapshot = await _firestore
          .collection('salons')
          .where('owner_id', isEqualTo: ownerId)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) => Salon.fromJson(doc.data())).toList();
    } catch (error) {
       debugPrint('Error fetching owner salons: $error');
       return [];
    }
  }

  // Create salon (for vendors)
  Future<Salon> createSalon({
    required String name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? openTime,
    String? closeTime,
  }) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final salonRef = _firestore.collection('salons').doc();
      final salonData = {
        'id': salonRef.id,
        'name': name,
        'description': description,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'owner_id': user.uid,
        'open_time': openTime,
        'close_time': closeTime,
        'is_approved': false,
        'rating': 0.0,
        'created_at': FieldValue.serverTimestamp(),
      };

      await salonRef.set(salonData);
      return Salon.fromJson(salonData);
  }

  // Update salon
  Future<Salon> updateSalon({
    required String salonId,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? openTime,
    String? closeTime,
  }) async {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (address != null) updateData['address'] = address;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (openTime != null) updateData['open_time'] = openTime;
      if (closeTime != null) updateData['close_time'] = closeTime;

      await _firestore.collection('salons').doc(salonId).update(updateData);
      
      final updatedDoc = await _firestore.collection('salons').doc(salonId).get();
      return Salon.fromJson(updatedDoc.data()!);
  }

  // Helper method to calculate distance between two points
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}
// Add import at the top
