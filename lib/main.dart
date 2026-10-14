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

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'firebase_options.dart';
import 'services/billing_service.dart';
import 'services/subscription_manager.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

void _installErrorCapture() {
  FlutterError.onError = (FlutterErrorDetails d) {
    FlutterError.presentError(d); // keeps the normal console output
    debugPrint('MYUPI_FLUTTER_ERROR: ${d.exceptionAsString()}\n${d.stack}');
  };
  PlatformDispatcher.instance.onError = (Object e, StackTrace s) {
    debugPrint('MYUPI_ASYNC_ERROR: $e\n$s');
    return true; // handled, don't crash
  };
  // Visible, tiny placeholder instead of a blank/grey box. Same in release.
  ErrorWidget.builder = (FlutterErrorDetails d) {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      color: const Color(0xFFFFF4E5),
      child: Text(
        kDebugMode ? d.exceptionAsString() : 'This section could not load.',
        style: const TextStyle(fontSize: 12, color: Color(0xFF8A4B00)),
      ),
    );
  };
}

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  _installErrorCapture();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Safety hard timeout (2s) to ensure splash is never stuck
  Future.delayed(const Duration(milliseconds: 2000), () {
    FlutterNativeSplash.remove();
  });

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
