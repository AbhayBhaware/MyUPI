// lib/main.dart
//
// MyUPI Soundbox — app entry point and routing shell.
// ----------------------------------------------------
// On launch, checks SharedPreferences (via Kotlin MethodChannel) to decide
// whether to show onboarding or jump straight to the main dashboard.
//
// All payment detection, TTS, and history storage happen in Kotlin.
// Flutter is purely the UI layer.
//
// Navigation (post-onboarding):
//   0: Home     — Soundbox dashboard
//   1: History  — Payment history list
//   2: Settings — Soundbox/TTS settings

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_channels.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding/onboarding_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_radius.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyUpiApp());
}

class MyUpiApp extends StatelessWidget {
  const MyUpiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyUPI Soundbox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppRouter(),
    );
  }
}

// ─── App router (onboarding gate) ────────────────────────────────────────────

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {

  /// null = still loading, true = onboarding done, false = needs onboarding.
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      await SubscriptionManager.instance.initialize();
      // Initialize Google Play Billing in background; failure never blocks startup
      BillingService.instance.initialize().catchError((_) {});
      final done = await kMethodChannel
          .invokeMethod<bool>('isOnboardingCompleted') ?? false;
      if (mounted) setState(() => _onboardingDone = done);
    } on PlatformException catch (_) {
      // If the call fails, treat as onboarding NOT done so user sees setup.
      if (mounted) setState(() => _onboardingDone = false);
    }
  }

  void _onOnboardingComplete() {
    // Called by the Ready screen after persisting the flag.
    if (mounted) setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading splash ────────────────────────────────────────────────────────
    if (_onboardingDone == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: AppRadius.lgRadius,
                ),
                child: const Icon(
                  Icons.speaker,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 6),
              Text(
                'Smart Payment Soundbox',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // ── Onboarding ────────────────────────────────────────────────────────────
    if (_onboardingDone == false) {
      return OnboardingShell(onComplete: _onOnboardingComplete);
    }

    // ── Main dashboard ────────────────────────────────────────────────────────
    return const _ShellPage();
  }
}

// ─── Navigation shell (post-onboarding) ──────────────────────────────────────

class _ShellPage extends StatefulWidget {
  const _ShellPage();

  @override
  State<_ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<_ShellPage> {
  int _selectedIndex = 0;

  void _navigateToTab(int index) {
    if (mounted) setState(() => _selectedIndex = index);
  }

  late final List<Widget> _pages = [
    HomeScreen(onNavigateToTab: _navigateToTab),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1.0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speaker_outlined),
              selectedIcon: Icon(Icons.speaker),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
