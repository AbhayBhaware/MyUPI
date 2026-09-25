// test/auth_gate_and_setup_test.dart
//
// Unit and Widget tests for MyUPI Welcome, Auth & Setup Flow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/models/user_profile.dart';
import 'package:myupi/screens/auth/welcome_screen.dart';
import 'package:myupi/screens/auth/phone_auth_screen.dart';
import 'package:myupi/screens/auth/email_auth_screen.dart';

void main() {
  group('UserProfile & Firestore Constants Tests', () {
    test('kFieldSetupComplete is strictly "setupComplete"', () {
      expect(kFieldSetupComplete, 'setupComplete');
      expect(kCollectionUsers, 'users');
    });

    test('kShopCategories contains required core business types', () {
      expect(kShopCategories, contains('Kirana / General Store'));
      expect(kShopCategories, contains('Restaurant / Food & Beverages'));
      expect(kShopCategories, contains('Clothing & Fashion'));
      expect(kShopCategories, contains('Electronics & Mobile'));
      expect(kShopCategories, contains('Salon & Personal Care'));
      expect(kShopCategories, contains('Medical & Pharmacy'));
      expect(kShopCategories, contains('Other'));
    });

    test('UserProfile serializes to map with setupComplete field', () {
      final profile = UserProfile(
        uid: 'merchant_123',
        ownerName: 'Abhay Bhaware',
        shopName: 'Abhay General Store',
        category: 'Kirana / General Store',
        phone: '+919876543210',
        email: 'abhay@example.com',
        authMethod: 'phone',
        setupComplete: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      final map = profile.toMap();
      expect(map[kFieldSetupComplete], isTrue);
      expect(map['ownerName'], 'Abhay Bhaware');
      expect(map['shopName'], 'Abhay General Store');
      expect(map['category'], 'Kirana / General Store');
      expect(map['phone'], '+919876543210');
      expect(map['email'], 'abhay@example.com');
      expect(map['authMethod'], 'phone');
    });

    test('UserProfile deserializes from Firestore map correctly', () {
      final firestoreMap = <String, dynamic>{
        'ownerName': 'Ramesh Kumar',
        'shopName': 'Ramesh Electronics',
        'category': 'Electronics & Mobile',
        'phone': '+919988776655',
        'email': 'ramesh@test.com',
        'authMethod': 'google',
        kFieldSetupComplete: true,
        'createdAt': '2026-03-01T10:00:00.000Z',
        'updatedAt': '2026-03-01T10:30:00.000Z',
      };

      final profile = UserProfile.fromMap('user_456', firestoreMap);
      expect(profile.uid, 'user_456');
      expect(profile.ownerName, 'Ramesh Kumar');
      expect(profile.shopName, 'Ramesh Electronics');
      expect(profile.category, 'Electronics & Mobile');
      expect(profile.phone, '+919988776655');
      expect(profile.email, 'ramesh@test.com');
      expect(profile.authMethod, 'google');
      expect(profile.setupComplete, isTrue);
    });

    test('UserProfile defaults setupComplete to false when missing', () {
      final incompleteMap = <String, dynamic>{
        'ownerName': 'New Merchant',
      };

      final profile = UserProfile.fromMap('user_new', incompleteMap);
      expect(profile.setupComplete, isFalse);
    });
  });

  group('WelcomeScreen Widget Tests', () {
    testWidgets('WelcomeScreen renders logo, title, and 3 auth entry points', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      expect(find.text('MyUPI'), findsOneWidget);
      expect(find.text('Smart Payment Soundbox for Indian Merchants'), findsOneWidget);

      // Verify the three distinct auth buttons
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Phone'), findsOneWidget);
      expect(find.text('Continue with Email'), findsOneWidget);

      // Verify feature highlights
      expect(find.text('Instant Voice Announcements'), findsOneWidget);
      expect(find.text('Universal UPI Compatibility'), findsOneWidget);
      expect(find.text('100% On-Device Reliability'), findsOneWidget);
    });
  });

  group('Auth Screens Widget Tests', () {
    testWidgets('PhoneAuthScreen renders mobile number input and +91 indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PhoneAuthScreen(),
        ),
      );

      expect(find.text('Enter your mobile number'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
    });

    testWidgets('EmailAuthScreen toggles between Log In and Create Account modes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmailAuthScreen(),
        ),
      );

      // Initially in Log In mode
      expect(find.text('Log In'), findsWidgets);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Confirm Password'), findsNothing);

      // Switch to Create Account mode
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Now Confirm Password should be present, Forgot password absent
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
    });
  });
}
