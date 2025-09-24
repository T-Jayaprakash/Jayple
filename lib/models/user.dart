class User {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? profileUrl;
  final String role;
  final bool verified;
  final DateTime? createdAt;

  User({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.profileUrl,
    this.role = 'customer',
    this.verified = false,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      profileUrl: json['profile_url'] as String?,
      role: json['role'] as String? ?? 'customer',
      verified: json['verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'profile_url': profileUrl,
      'role': role,
      'verified': verified,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? profileUrl,
    String? role,
    bool? verified,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      profileUrl: profileUrl ?? this.profileUrl,
      role: role ?? this.role,
      verified: verified ?? this.verified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
