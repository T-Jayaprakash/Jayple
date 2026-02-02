import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String? userId;
  final String? salonId;
  final String? serviceId;
  final String? assignedFreelancerId;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final bool homeService;
  final DateTime? createdAt;

  Booking({
    required this.id,
    this.userId,
    this.salonId,
    this.serviceId,
    this.assignedFreelancerId,
    required this.startAt,
    required this.endAt,
    this.status = 'pending',
    this.homeService = false,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      salonId: json['salon_id'] as String?,
      serviceId: json['service_id'] as String?,
      assignedFreelancerId: json['assigned_freelancer_id'] as String?,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      status: json['status'] as String? ?? 'pending',
      homeService: json['home_service'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? (json['created_at'] is Timestamp 
              ? (json['created_at'] as Timestamp).toDate() 
              : DateTime.parse(json['created_at'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'salon_id': salonId,
      'service_id': serviceId,
      'assigned_freelancer_id': assignedFreelancerId,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'status': status,
      'home_service': homeService,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? salonId,
    String? serviceId,
    String? assignedFreelancerId,
    DateTime? startAt,
    DateTime? endAt,
    String? status,
    bool? homeService,
    DateTime? createdAt,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      salonId: salonId ?? this.salonId,
      serviceId: serviceId ?? this.serviceId,
      assignedFreelancerId: assignedFreelancerId ?? this.assignedFreelancerId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      homeService: homeService ?? this.homeService,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods for UI
  String get displayStatus {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String get displayDate {
    final now = DateTime.now();
    final bookingDate = DateTime(startAt.year, startAt.month, startAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    if (bookingDate == today) {
      return 'Today';
    } else if (bookingDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${startAt.day}/${startAt.month}/${startAt.year}';
    }
  }

  String get displayTime {
    return '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')} - ${endAt.hour.toString().padLeft(2, '0')}:${endAt.minute.toString().padLeft(2, '0')}';
  }
}
