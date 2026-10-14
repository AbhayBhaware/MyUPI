// test/database_sync_and_security_test.dart
//
// Tests for FirestoreService offline persistence, security hardening,
// and split-brain sync fixes.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myupi/models/user_profile.dart';
import 'package:myupi/services/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FirestoreService.instance.clearLocalCache();
  });

  group('Database Security & Offline Resilience Tests', () {
    test('findDuplicateAccount returns null safely without throwing or bulk query', () async {
      final result = await FirestoreService.instance.findDuplicateAccount(
        currentUid: 'uid_test_1',
        phone: '+919876543210',
        email: 'test@example.com',
      );
      expect(result, isNull);
    });

    test('saveUserProfile saves to persistent local SharedPreferences cache immediately', () async {
      final profile = UserProfile(
        uid: 'user_offline_1',
        ownerName: 'Test Owner',
        shopName: 'Test Shop Name',
        category: 'Kirana / General Store',
        phone: '+919999999999',
        email: 'test@offline.com',
        authMethod: 'phone',
        upiId: 'test@upi',
        setupComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // saveUserProfile updates local cache immediately before remote call
      await FirestoreService.instance.saveUserProfile(profile);

      // Verify in-memory cache
      expect(FirestoreService.instance.cachedProfile?.shopName, 'Test Shop Name');

      // Verify SharedPreferences persistent cache
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString('cached_user_profile_user_offline_1');
      expect(storedJson, isNotNull);

      final map = jsonDecode(storedJson!) as Map<String, dynamic>;
      expect(map['shopName'], 'Test Shop Name');
      expect(map['upiId'], 'test@upi');
      expect(map['setupComplete'], isTrue);
    });

    test('getUserProfile restores profile from local cache when remote fails', () async {
      final prefs = await SharedPreferences.getInstance();
      final rawData = {
        'ownerName': 'Cached Merchant',
        'shopName': 'Aatta Chakki',
        'category': 'Kirana / General Store',
        'phone': '+918888888888',
        'email': 'chakki@example.com',
        'authMethod': 'phone',
        'upiId': 'chakki@upi',
        'setupComplete': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString('cached_user_profile_merchant_offline_99', jsonEncode(rawData));

      // Clear memory cache so it must read from SharedPreferences
      FirestoreService.instance.clearLocalCache();
      expect(FirestoreService.instance.cachedProfile, isNull);

      // Calling getUserProfile without valid firebase auth / network will trigger offline fallback
      final restored = await FirestoreService.instance.getUserProfile('merchant_offline_99');

      expect(restored, isNotNull);
      expect(restored!.shopName, 'Aatta Chakki');
      expect(restored.upiId, 'chakki@upi');
      expect(restored.setupComplete, isTrue);
      expect(FirestoreService.instance.cachedProfile?.shopName, 'Aatta Chakki');
    });

    test('deleteUserProfile clears both SharedPreferences and memory cache', () async {
      final profile = UserProfile(
        uid: 'user_delete_test',
        ownerName: 'Delete Owner',
        shopName: 'To Be Deleted',
        category: 'Other',
        phone: '+917777777777',
        email: 'del@example.com',
        authMethod: 'email',
        upiId: 'del@upi',
        setupComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirestoreService.instance.saveUserProfile(profile);
      expect(FirestoreService.instance.cachedProfile, isNotNull);

      await FirestoreService.instance.deleteUserProfile('user_delete_test');

      expect(FirestoreService.instance.cachedProfile, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_user_profile_user_delete_test'), isNull);
    });
  });
}
