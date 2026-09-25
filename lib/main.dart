// lib/main.dart
//
// MyUPI Soundbox — App entry point.
// ---------------------------------
// Routes exclusively through AuthGate:
// - Not logged in -> Welcome / Auth Screen
// - Logged in & setup incomplete -> Setup Wizard Screen (unskippable)
// - Logged in & setupComplete == true in Firestore -> Home Dashboard (ShellPage)
//
// All payment detection, TTS, and native ledger run in Kotlin.
// Flutter is purely the UI layer.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'services/billing_service.dart';
import 'services/subscription_manager.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Non-blocking background billing initialization
  SubscriptionManager.instance.initialize().catchError((_) {});
  BillingService.instance.initialize().catchError((_) {});

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
      home: const AuthGate(),
    );
  }
}
