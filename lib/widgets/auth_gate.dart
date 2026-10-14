// lib/widgets/auth_gate.dart
//
// Root AuthGate router for MyUPI Soundbox.
// -----------------------------------------
// Single source of truth for app routing:
// 1. Listens to FirebaseAuth.authStateChanges().
// 2. If user == null: renders WelcomeScreen (only entry point).
// 3. If user != null: awaits users/{uid} from Firestore.
//    - If doc doesn't exist OR setupComplete != true: renders SetupWizardScreen.
//    - Else: renders ShellPage (Home dashboard).
//
// Explicit guardrails against AI-generated auth bugs:
// - No hardcoded default route: main.dart routes through AuthGate every time.
// - No optimistic navigation: awaits Firestore before deciding destination.
// - References shared kFieldSetupComplete constant from user_profile.dart.
// - Back button blocked in Setup wizard.
// - Firestore is source of truth (no local SharedPreferences drift).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../app_channels.dart';
import '../models/user_profile.dart';
import '../screens/auth/setup_wizard_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/shell_page.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnapshot) {
        // ── 1. Auth state loading ─────────────────────────────────────────────
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _HomeSkeletonPlaceholder();
        }

        final user = authSnapshot.data;

        // ── 2. Not logged in -> Welcome Screen ────────────────────────────────
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FlutterNativeSplash.remove();
          });
          return const WelcomeScreen();
        }

        // ── 3. Authenticated -> Read Firestore users/{uid} ────────────────────
        return _FirestoreProfileGate(user: user);
      },
    );
  }
}

class _FirestoreProfileGate extends StatefulWidget {
  final User user;
  const _FirestoreProfileGate({required this.user});

  @override
  State<_FirestoreProfileGate> createState() => _FirestoreProfileGateState();
}

class _FirestoreProfileGateState extends State<_FirestoreProfileGate> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void didUpdateWidget(covariant _FirestoreProfileGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await FirestoreService.instance
          .getUserProfile(widget.user.uid, user: widget.user);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });

        // Push shop name to native Android Kotlin storage for audio engine
        if (profile != null && profile.shopName.trim().isNotEmpty) {
          try {
            await kMethodChannel.invokeMethod('setMerchantName', {'name': profile.shopName.trim()});
            await kMethodChannel.invokeMethod('setIncludeShopName', {'enabled': true});
          } catch (e) {
            debugPrint('[AuthGate] Method channel sync error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthGate] Error reading profile: $e');
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        final isPermission =
            errStr.contains('permission') || errStr.contains('401') || errStr.contains('403');
        setState(() {
          _errorMessage = isPermission
              ? 'Database permission denied. Please publish the Realtime Database security rules in Firebase Console.'
              : 'Unable to connect to database. Please tap Retry or continue to Setup.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSetupFinished() {
    // Re-read profile after wizard completion
    _fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _HomeSkeletonPlaceholder();
    }

    // Dismiss splash screen once destination screen is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Database Connection',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _fetchProfile,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry Connection'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _profile = null; // Opens Setup Wizard
                    });
                  },
                  child: const Text('Set Up Shop Profile'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => AuthService.instance.signOut(),
                  child: const Text('Sign Out', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Check if setup is complete using shared constant ────────────────────
    final isComplete = _profile != null && _profile!.setupComplete;

    if (!isComplete) {
      // Show Setup Wizard — unskippable and back-button blocked
      return SetupWizardScreen(
        user: widget.user,
        onSetupComplete: _onSetupFinished,
      );
    }

    // ── Setup complete -> Show Home dashboard ────────────────────────────────
    return const ShellPage();
  }
}

/// Home layout placeholder skeleton displayed while auth/profile is loading.
/// Prevents blank flash and avoids isolated spinners per Android launch guidelines.
class _HomeSkeletonPlaceholder extends StatelessWidget {
  const _HomeSkeletonPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Skeleton: Logo + Shop Name + Volume Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 120,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 76,
                    height: 32,
                    decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Status Card Skeleton
              Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 12),
              // Last Payment Hero Card Skeleton
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 12),
              // QR Card Skeleton
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
