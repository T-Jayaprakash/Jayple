import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/phone_input_screen.dart';
import '../../features/auth/otp_verify_screen.dart';
import 'auth_controller.dart';
import '../routing/role_router.dart';
import '../state/role_selection_guard.dart';
import 'user_model.dart';
import '../../services/auth_service.dart';
import '../../features/role_selection/role_selection_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Used to force re-build/re-fetch
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthStatus>(
      valueListenable: AuthController.instance.status,
      builder: (context, status, child) {
        switch (status) {
          case AuthStatus.unauthenticated:
            return const PhoneInputScreen();
          case AuthStatus.otpSent:
            return const OtpVerifyScreen();
          case AuthStatus.authenticated:
            return FutureBuilder<AppUser>(
              key: ValueKey(_refreshKey), // Force refresh when key changes
              future: AuthService.instance.fetchUser(
                 FirebaseAuth.instance.currentUser?.uid ?? ''
              ),
              builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Scaffold(body: Center(child: CircularProgressIndicator()));
                 }
                 if (snapshot.hasError || !snapshot.hasData) {
                    // If fetching fails, sign out to reset state
                    // AuthController.instance.signOut(); 
                    // Or show retry
                    return Scaffold(
                      body: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Failed to load profile"),
                          ElevatedButton(
                            onPressed: () => setState(() => _refreshKey++),
                            child: const Text("Retry"),
                          )
                        ],
                      )
                    );
                 }
                 final user = snapshot.data!;
                 if (RoleSelectionGuard.needsRoleSelection(user)) {
                   return RoleSelectionScreen(
                      user: user, 
                      onRoleSelected: () { 
                         setState(() => _refreshKey++);
                      }
                   );
                 }
                 return RoleRouter(user: user);
              },
            );
        }
      },
    );
  }
}
