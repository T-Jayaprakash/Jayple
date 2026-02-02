class AppUser {
  final String uid;
  final List<String> roles;
  final String? activeRole; // Nullable to support first-time users
  final String status;

  AppUser({
    required this.uid,
    required this.roles,
    this.activeRole,
    required this.status,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    if (!data.containsKey('roles')) throw FormatException('Contract Violation: Missing roles');
    // activeRole check removed to allow missing field
    if (!data.containsKey('status')) throw FormatException('Contract Violation: Missing status');

    return AppUser(
      uid: uid,
      roles: List<String>.from(data['roles']),
      activeRole: data['activeRole'] as String?,
      status: data['status'],
    );
  }
}
