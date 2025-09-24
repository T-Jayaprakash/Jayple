import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as user_model;

class AuthService {
  // Sign in with phone (send OTP)
  Future<void> signInWithPhone(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } catch (error) {
      throw Exception('Phone sign-in failed: $error');
    }
  }

  // Verify OTP
  Future<AuthResponse> verifyOtp(
      {required String phone, required String token}) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      return response;
    } catch (error) {
      throw Exception('OTP verification failed: $error');
    }
  }

  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Get current user
  user_model.User? get currentUser {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;

    return user_model.User(
      id: authUser.id,
      email: authUser.email,
      fullName: authUser.userMetadata?['full_name'],
      phone: authUser.phone,
      profileUrl: authUser.userMetadata?['avatar_url'],
      role: authUser.userMetadata?['role'] ?? 'customer',
    );
  }

  // Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  // Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw Exception('Sign out failed: $error');
    }
  }

  // Update user profile
  Future<UserResponse> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(
          data: {
            if (fullName != null) 'full_name': fullName,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
          phone: phone,
        ),
      );
      return response;
    } catch (error) {
      throw Exception('Profile update failed: $error');
    }
  }

  // Listen to auth state changes
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  // Get user profile from database
  Future<user_model.User?> getUserProfile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response =
          await _client.from('users').select().eq('id', userId).single();

      return user_model.User.fromJson(response);
    } catch (error) {
      // User might not exist in users table yet
      return currentUser;
    }
  }

  // Create or update user profile in database
  Future<user_model.User> createOrUpdateUserProfile({
    required String phone,
    String? fullName,
    String? profileUrl,
    String role = 'customer',
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final userData = {
        'id': userId,
        'phone': phone,
        'full_name': fullName,
        'profile_url': profileUrl,
        'role': role,
        'verified': false,
      };

      final response =
          await _client.from('users').upsert(userData).select().single();

      return user_model.User.fromJson(response);
    } catch (error) {
      throw Exception('Profile creation failed: $error');
    }
  }
}
