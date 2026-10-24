import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/screens/about_screen.dart';
import 'package:myupi/screens/help_support_screen.dart';
import 'package:myupi/screens/reliability_checklist_screen.dart';
import 'package:myupi/screens/diagnostics_screen.dart';
import 'package:myupi/screens/onboarding/step_notif_screen.dart';
import 'package:myupi/screens/onboarding/step_sound_screen.dart';
import 'package:myupi/screens/onboarding/step_test_sound_screen.dart';
import 'package:myupi/screens/onboarding/step_ready_screen.dart';
import 'package:myupi/screens/onboarding/step_premium_intro_screen.dart';
import 'package:myupi/screens/auth/email_auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.myupi.soundbox/notification_access');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return null;
    });
  });

  Widget buildHost(Widget screen, {double width = 360}) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: const TextScaler.linear(1.0),
      ),
      child: MaterialApp(
        home: Material(child: screen),
      ),
    );
  }

  final screens = <String, Widget>{
    'AboutScreen': const AboutScreen(),
    'HelpSupportScreen': const HelpSupportScreen(),
    'ReliabilityChecklistScreen': const ReliabilityChecklistScreen(),
    'DiagnosticsScreen': const DiagnosticsScreen(),
    'StepNotifScreen': StepNotifScreen(onContinue: () {}),
    'StepSoundScreen': StepSoundScreen(onContinue: () {}),
    'StepTestSoundScreen': StepTestSoundScreen(onContinue: () {}),
    'StepReadyScreen': StepReadyScreen(onFinish: () {}, notifAccessGranted: true, soundboxEnabled: true),
    'StepPremiumIntroScreen': StepPremiumIntroScreen(onFinish: () {}),
    'EmailAuthScreen': const EmailAuthScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('Audit overflow for ${entry.key}', (tester) async {
      final List<String> overflows = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          debugPrint('DEBUG OVERFLOW CAUGHT:\n${details.toString()}');
          overflows.add(details.exceptionAsString());
        } else {
          originalOnError?.call(details);
        }
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      for (final w in [320.0, 360.0, 411.0]) {
        tester.view.physicalSize = Size(w * 2, 800 * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(buildHost(entry.value, width: w));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      FlutterError.onError = originalOnError;
      expect(overflows, isEmpty, reason: 'Found layout overflows in ${entry.key}: ${overflows.join("; ")}');
    });
  }
}
