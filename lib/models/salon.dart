class Salon {
  final String id;
  final String name;
  final String? description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? ownerId;
  final double rating;
  final bool isApproved;
  final String? openTime;
  final String? closeTime;
  final DateTime? createdAt;

  Salon({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.ownerId,
    this.rating = 0.0,
    this.isApproved = false,
    this.openTime,
    this.closeTime,
    this.createdAt,
  });

  factory Salon.fromJson(Map<String, dynamic> json) {
    return Salon(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      imageUrl: json['image_url'] as String?,
      ownerId: json['owner_id'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      isApproved: json['is_approved'] as bool? ?? false,
      openTime: json['open_time'] as String?,
      closeTime: json['close_time'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imageUrl,
      'owner_id': ownerId,
      'rating': rating,
      'is_approved': isApproved,
      'open_time': openTime,
      'close_time': closeTime,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Salon copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? ownerId,
    double? rating,
    bool? isApproved,
    String? openTime,
    String? closeTime,
    DateTime? createdAt,
  }) {
    return Salon(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      rating: rating ?? this.rating,
      isApproved: isApproved ?? this.isApproved,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods for UI
  String get displayAddress => address ?? 'Address not available';
  String get displayRating => rating.toStringAsFixed(1);
  bool get isOpen {
    if (openTime == null || closeTime == null) return true;
    final now = DateTime.now();
    final currentTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00";
    return currentTime.compareTo(openTime!) >= 0 &&
        currentTime.compareTo(closeTime!) <= 0;
  }
}
