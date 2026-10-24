import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/app_channels.dart';
import 'package:myupi/screens/settings_screen.dart';
import 'package:myupi/utils/speech_template_builder.dart';

void main() {
  test('Test RegExp in SpeechTemplateBuilder', () {
    expect(() => SpeechTemplateBuilder.sanitizeShopName('Abhay Kirana & Store 123! @#'), returnsNormally);
    expect(() => SpeechTemplateBuilder.sanitizeShopName('रमेश किराना स्टोर'), returnsNormally);
    expect(() => SpeechTemplateBuilder.sanitizeShopName('రమేష్ కిరాణా'), returnsNormally);
    expect(() => SpeechTemplateBuilder.getFormatPreviewText(format: 'A', langCode: 'hi-IN', merchantName: 'Test'), returnsNormally);
  });

  testWidgets('SettingsScreen state permutations test', (tester) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() {
      FlutterError.onError = originalOnError;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.myupi.soundbox/notification_access'),
        null,
      );
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.myupi.soundbox/notification_access'),
      (call) async {
        switch (call.method) {
          case 'isSoundboxEnabled': return true;
          case 'getLanguage': return 'en-IN';
          case 'getAnnouncementFormat': return 'A';
          case 'getSpeechSpeed': return 'normal';
          case 'isIncomingOnly': return false;
          case 'getMerchantName': return 'Test Shop';
          default: return null;
        }
      },
    );
    FlutterErrorDetails? caughtDetails;
    FlutterError.onError = (details) {
      caughtDetails = details;
      debugPrint('CRASH DETECTED: ${details.exception}');
      debugPrint('STACK: ${details.stack}');
    };

    // Test across various subscription states
    for (final state in SubscriptionState.values) {
      SubscriptionManager.instance.subscriptionInfoNotifier.value =
          SubscriptionInfo(state: state);

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 4));

      if (caughtDetails != null) {
        fail('SettingsScreen crashed with state $state: ${caughtDetails!.exception}');
      }
    }
  });
}
