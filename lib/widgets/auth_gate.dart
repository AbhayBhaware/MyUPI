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

import '../models/user_profile.dart';
import '../screens/auth/setup_wizard_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/shell_page.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
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
          return const _AuthLoadingSplash();
        }

        final user = authSnapshot.data;

        // ── 2. Not logged in -> Welcome Screen ────────────────────────────────
        if (user == null) {
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
      return const _AuthLoadingSplash();
    }

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

class _AuthLoadingSplash extends StatelessWidget {
  const _AuthLoadingSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.xlRadius,
                border: Border.all(color: AppColors.softBlueBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withAlpha(25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: AppRadius.xlRadius,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'assets/icon/icon_foreground.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.speaker,
                      size: 48,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'MyUPI',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}
