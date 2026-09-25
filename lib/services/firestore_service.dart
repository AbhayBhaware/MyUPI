// lib/services/firestore_service.dart
//
// Realtime Database & Profile Service for MyUPI.
// ------------------------------------------------
// Communicates with Firebase Realtime Database (provisioned at
// https://myupi1-default-rtdb.firebaseio.com) via REST API with the
// authenticated Firebase user's ID token.
//
// Guarantees:
// 1. Single source of truth: reads /users/{uid}.json from Realtime Database.
// 2. Uses shared kFieldSetupComplete and kCollectionUsers constants.
// 3. Exposes reactive UserProfile stream & in-memory cache.
// 4. Detailed debug logging before and after every read & write.
// 5. Does NOT falsely report victory if remote write fails.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user_profile.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  static const String projectId = 'myupi1';
  static const String rtdbUrl = 'https://myupi1-default-rtdb.firebaseio.com';

  final _client = http.Client();

  User? get _currentUser {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance.currentUser;
      }
    } catch (_) {}
    return null;
  }

  // In-memory cache of current profile
  UserProfile? _cachedProfile;
  UserProfile? get cachedProfile => _cachedProfile;

  final _profileController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get profileStream => _profileController.stream;

  /// Retrieves the merchant's profile from `/users/{uid}.json`.
  /// Returns null if document does not exist (genuine new user).
  /// Throws on network or permission errors so AuthGate can display Retry.
  Future<UserProfile?> getUserProfile(String uid, {User? user}) async {
    final effectiveUser = user ?? _currentUser;
    // Force refresh token to ensure it hasn't expired
    final token = await effectiveUser?.getIdToken(true);

    final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
    final url = '$rtdbUrl/$kCollectionUsers/$uid.json$authParam';
    debugPrint('[DatabaseService] ─── GET User Profile ───');
    debugPrint('[DatabaseService] URL: $rtdbUrl/$kCollectionUsers/$uid.json (auth token present: ${token != null})');
    debugPrint('[DatabaseService] UID: $uid');

    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final res = await _client.get(uri, headers: headers).timeout(
          const Duration(seconds: 10),
        );

    debugPrint('[DatabaseService] RTDB Read Response: [${res.statusCode}] ${res.body}');

    if (res.statusCode == 200) {
      if (res.body.trim() == 'null' || res.body.trim().isEmpty) {
        debugPrint('[DatabaseService] Profile not found for $uid -> New User');
        _cachedProfile = null;
        _profileController.add(null);
        return null;
      }

      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        final profile = UserProfile.fromMap(uid, body);
        _cachedProfile = profile;
        _profileController.add(profile);
        debugPrint('[DatabaseService] Profile Loaded: ${profile.shopName}, setupComplete=${profile.setupComplete}');
        return profile;
      } else {
        _cachedProfile = null;
        _profileController.add(null);
        return null;
      }
    } else if (res.statusCode == 401 || res.statusCode == 403) {
      debugPrint('[DatabaseService] PERMISSION DENIED on read! Check Realtime Database rules in Firebase Console.');
      throw HttpException('Database permission denied (${res.statusCode}). Check Realtime Database rules.');
    } else {
      debugPrint('[DatabaseService] Unexpected status: ${res.statusCode} ${res.body}');
      throw HttpException('Failed to load profile (${res.statusCode})');
    }
  }

  /// Writes merchant profile to `/users/{uid}.json` with `setupComplete: true`.
  /// Returns true only if write was confirmed by server (HTTP 200-299).
  Future<bool> saveUserProfile(UserProfile profile) async {
    try {
      final user = _currentUser;
      final token = await user?.getIdToken(true);

      final dataMap = profile.toMap();
      final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
      final url = '$rtdbUrl/$kCollectionUsers/${profile.uid}.json$authParam';
      final bodyPayload = jsonEncode(dataMap);

      debugPrint('[DatabaseService] ─── PUT User Profile ───');
      debugPrint('[DatabaseService] URL: $rtdbUrl/$kCollectionUsers/${profile.uid}.json (auth token present: ${token != null})');
      debugPrint('[DatabaseService] Payload: $bodyPayload');

      final uri = Uri.parse(url);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final res = await _client.put(uri, headers: headers, body: bodyPayload).timeout(
            const Duration(seconds: 12),
          );

      debugPrint('[DatabaseService] RTDB Write Response: [${res.statusCode}] ${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _cachedProfile = profile;
        _profileController.add(profile);
        debugPrint('[DatabaseService] Profile saved successfully to RTDB with setupComplete=true!');
        return true;
      } else {
        debugPrint('[DatabaseService] FAILED to save profile: status=${res.statusCode}, body=${res.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[DatabaseService] Exception saving profile: $e');
      return false;
    }
  }

  /// Detects if another merchant profile with matching phone or email
  /// already exists in Realtime Database under a different UID.
  Future<String?> findDuplicateAccount({
    required String currentUid,
    String? phone,
    String? email,
  }) async {
    try {
      final user = _currentUser;
      final token = await user?.getIdToken();

      final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
      final url = '$rtdbUrl/$kCollectionUsers.json$authParam';
      final uri = Uri.parse(url);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final res = await _client.get(uri, headers: headers).timeout(
            const Duration(seconds: 6),
          );

      if (res.statusCode == 200 && res.body.trim() != 'null') {
        final allUsers = jsonDecode(res.body);
        if (allUsers is Map<String, dynamic>) {
          for (final entry in allUsers.entries) {
            final uid = entry.key;
            if (uid == currentUid) continue;

            final userMap = entry.value;
            if (userMap is Map<String, dynamic>) {
              final existingPhone = userMap['phone'] as String?;
              final existingEmail = userMap['email'] as String?;

              if (phone != null && phone.isNotEmpty && existingPhone == phone) {
                final maskedPhone = phone.length > 4
                    ? '${phone.substring(0, 3)}****${phone.substring(phone.length - 3)}'
                    : phone;
                return 'This mobile number ($maskedPhone) is already registered to an existing MyUPI account.';
              }
              if (email != null && email.isNotEmpty && existingEmail == email) {
                return 'This email ($email) is already linked to an existing MyUPI account.';
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      // Non-blocking duplicate detection failure
      debugPrint('[DatabaseService] Duplicate account check skipped: $e');
      return null;
    }
  }

  /// Clears in-memory profile cache on sign out.
  void clearLocalCache() {
    _cachedProfile = null;
    _profileController.add(null);
    debugPrint('[DatabaseService] Local profile cache cleared.');
  }

  /// Disposes resources
  void dispose() {
    _profileController.close();
    _client.close();
  }
}
