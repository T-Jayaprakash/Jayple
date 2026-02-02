import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'user_model.dart';
import '../routing/role_router.dart';
import '../state/role_selection_guard.dart';
import '../state/app_lifecycle_listener.dart';
import '../../features/auth/otp_login_screen.dart';
import '../../features/blocked/blocked_screen.dart';
import '../../features/role_selection/role_selection_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Used to force a re-fetch of the user document
  // when role selection updates the backend OR app resumes.
  int _refreshKey = 0;

  void _refreshUserData() {
    if (mounted) {
      debugPrint('AuthGate: App resumed or role updated. Refreshing user data...');
      setState(() {
        _refreshKey++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // B1.3: Wrap with AppLifecycleListener to trigger refresh on resume
    return AppLifecycleListener(
      onAppResumed: _refreshUserData,
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Waiting for Auth State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // 2. Not Logged In
          if (!snapshot.hasData || snapshot.data == null) {
            return const OtpLoginScreen();
          }

          final User firebaseUser = snapshot.data!;

          // 3. Fetch User Document (Once per refresh)
          return FutureBuilder<AppUser>(
            key: ValueKey<int>(_refreshKey), // Ensures logic re-runs on refresh
            future: AuthService().fetchUser(firebaseUser.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                // Show spinner while validating session/re-fetching
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (userSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Session Validation Failed',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${userSnapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => AuthService().signOut(), 
                            child: const Text('Sign Out / Retry'),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (!userSnapshot.hasData) {
                 return const Scaffold(body: Center(child: Text('Fatal Error: No user data returned')));
              }

              final AppUser appUser = userSnapshot.data!;

              // 4. Block Enforcement (Re-checked on resume)
              if (appUser.status != 'active') {
                 return const BlockedScreen();
              }

              // 5. Role Selection Logic (B1.2) (Re-checked on resume)
              if (RoleSelectionGuard.needsRoleSelection(appUser)) {
                return RoleSelectionScreen(
                  user: appUser,
                  onRoleSelected: _refreshUserData,
                );
              }

              // 6. Role Routing (B1.1)
              return RoleRouter(user: appUser);
            },
          );
        },
      ),
    );
  }
}
