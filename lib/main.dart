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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B21B6),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
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
      final done = await kMethodChannel
          .invokeMethod<bool>('isOnboardingCompleted') ?? false;
      if (mounted) setState(() => _onboardingDone = done);
    } on PlatformException catch (_) {
      // If the call fails (e.g. old install without the handler), treat
      // as onboarding NOT done so the user still sees setup.
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.speaker,
                size: 56,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('MyUPI',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
          ]),
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

  static const _pages = <Widget>[
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speaker_outlined),
            selectedIcon: Icon(Icons.speaker),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
