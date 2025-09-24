class Service {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;
  final String? imageUrl;
  final String? salonId;
  final DateTime? createdAt;

  Service({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.imageUrl,
    this.salonId,
    this.createdAt,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      durationMinutes: json['duration_minutes'] as int,
      imageUrl: json['image_url'] as String?,
      salonId: json['salon_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'duration_minutes': durationMinutes,
      'image_url': imageUrl,
      'salon_id': salonId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Service copyWith({
    String? id,
    String? name,
    double? price,
    int? durationMinutes,
    String? imageUrl,
    String? salonId,
    DateTime? createdAt,
  }) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      imageUrl: imageUrl ?? this.imageUrl,
      salonId: salonId ?? this.salonId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods for UI
  String get displayPrice => '₹${price.toStringAsFixed(0)}';
  String get displayDuration {
    if (durationMinutes >= 60) {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    }
    return '${durationMinutes}m';
  }
}
