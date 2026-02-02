import '../auth/user_model.dart';

class RoleSelectionGuard {
  static bool needsRoleSelection(AppUser user) {
    if (user.activeRole == null || user.activeRole!.isEmpty) return true;
    if (!user.roles.contains(user.activeRole)) return true;
    return false;
  }
}
