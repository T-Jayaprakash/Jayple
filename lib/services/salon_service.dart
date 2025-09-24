import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/salon.dart';

class SalonService {
  static SalonService? _instance;
  static SalonService get instance => _instance ??= SalonService._();

  SalonService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Get all salons
  Future<List<Salon>> getAllSalons({
    int limit = 50,
    double? latitude,
    double? longitude,
  }) async {
    try {
      var query = _client
          .from('salons')
          .select()
          .eq('is_approved', true)
          .order('rating', ascending: false)
          .limit(limit);

      final response = await query;
      return response.map<Salon>((json) => Salon.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Failed to fetch salons: $error');
    }
  }

  // Get salons near location
  Future<List<Salon>> getNearBySalons({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('salons')
          .select()
          .eq('is_approved', true)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .order('rating', ascending: false)
          .limit(limit);

      final salons =
          response.map<Salon>((json) => Salon.fromJson(json)).toList();

      // Filter by distance (simple calculation - in production use PostGIS)
      return salons.where((salon) {
        if (salon.latitude == null || salon.longitude == null) return false;
        final distance = _calculateDistance(
            latitude, longitude, salon.latitude!, salon.longitude!);
        return distance <= radiusKm;
      }).toList();
    } catch (error) {
      throw Exception('Failed to fetch nearby salons: $error');
    }
  }

  // Search salons
  Future<List<Salon>> searchSalons({
    required String query,
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('salons')
          .select()
          .eq('is_approved', true)
          .or('name.ilike.%$query%,description.ilike.%$query%,address.ilike.%$query%')
          .order('rating', ascending: false)
          .limit(limit);

      return response.map<Salon>((json) => Salon.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Failed to search salons: $error');
    }
  }

  // Get salon by ID with services
  Future<Map<String, dynamic>> getSalonWithServices(String salonId) async {
    try {
      // Get salon details
      final salonResponse = await _client
          .from('salons')
          .select()
          .eq('id', salonId)
          .eq('is_approved', true)
          .single();

      // Get salon services
      final servicesResponse = await _client
          .from('services')
          .select()
          .eq('salon_id', salonId)
          .order('price', ascending: true);

      return {
        'salon': Salon.fromJson(salonResponse),
        'services': servicesResponse,
      };
    } catch (error) {
      throw Exception('Failed to fetch salon details: $error');
    }
  }

  // Get salons by owner
  Future<List<Salon>> getSalonsByOwner(String ownerId) async {
    try {
      final response = await _client
          .from('salons')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      return response.map<Salon>((json) => Salon.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Failed to fetch owner salons: $error');
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
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final salonData = {
        'name': name,
        'description': description,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'owner_id': userId,
        'open_time': openTime,
        'close_time': closeTime,
        'is_approved': false, // Requires admin approval
        'rating': 0.0,
      };

      final response =
          await _client.from('salons').insert(salonData).select().single();

      return Salon.fromJson(response);
    } catch (error) {
      throw Exception('Failed to create salon: $error');
    }
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
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (address != null) updateData['address'] = address;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (openTime != null) updateData['open_time'] = openTime;
      if (closeTime != null) updateData['close_time'] = closeTime;

      final response = await _client
          .from('salons')
          .update(updateData)
          .eq('id', salonId)
          .select()
          .single();

      return Salon.fromJson(response);
    } catch (error) {
      throw Exception('Failed to update salon: $error');
    }
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
