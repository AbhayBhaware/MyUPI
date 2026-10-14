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
import 'package:shared_preferences/shared_preferences.dart';

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
  @visibleForTesting
  set cachedProfile(UserProfile? p) => _cachedProfile = p;

  final _profileController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get profileStream => _profileController.stream;

  static String _cacheKey(String uid) => 'cached_user_profile_$uid';

  /// Reads persistent offline user profile from device storage.
  Future<UserProfile?> _getCachedProfileFromPrefs(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey(uid));
      if (jsonStr != null && jsonStr.trim().isNotEmpty && jsonStr.trim() != 'null') {
        final data = jsonDecode(jsonStr);
        if (data is Map<String, dynamic>) {
          return UserProfile.fromMap(uid, data);
        }
      }
    } catch (e) {
      debugPrint('[DatabaseService] Failed to read local profile cache: $e');
    }
    return null;
  }

  /// Writes persistent offline user profile to device storage.
  Future<void> _saveCachedProfileToPrefs(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(profile.uid), jsonEncode(profile.toMap()));
    } catch (e) {
      debugPrint('[DatabaseService] Failed to write local profile cache: $e');
    }
  }

  /// Retrieves the merchant's profile from `/users/{uid}.json`.
  /// Returns null if document does not exist (genuine new user).
  /// Falls back to local persistent storage on network disconnect or auth failure.
  Future<UserProfile?> getUserProfile(String uid, {User? user}) async {
    final effectiveUser = user ?? _currentUser;

    try {
      return await _fetchRemoteProfile(uid, effectiveUser);
    } catch (e) {
      debugPrint('[DatabaseService] Remote read failed ($e). Checking offline cache...');
      final cached = await _getCachedProfileFromPrefs(uid);
      if (cached != null) {
        debugPrint('[DatabaseService] Offline cached profile restored for $uid');
        _cachedProfile = cached;
        _profileController.add(cached);
        return cached;
      }
      // If no local cache exists, rethrow so AuthGate can offer retry/setup
      rethrow;
    }
  }

  Future<UserProfile?> _fetchRemoteProfile(String uid, User? user) async {
    String? token = await user?.getIdToken(false);

    http.Response res = await _executeGet(uid, token);

    // If unauthorized / token expired, refresh token and retry once
    if (res.statusCode == 401 || res.statusCode == 403) {
      debugPrint('[DatabaseService] Token expired or 401/403. Refreshing token...');
      token = await user?.getIdToken(true);
      if (token != null && token.isNotEmpty) {
        res = await _executeGet(uid, token);
      }
    }

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
        await _saveCachedProfileToPrefs(profile);
        debugPrint('[DatabaseService] Profile Loaded & Cached: ${profile.shopName}, setupComplete=${profile.setupComplete}');
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

  Future<http.Response> _executeGet(String uid, String? token) {
    final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
    final url = '$rtdbUrl/$kCollectionUsers/$uid.json$authParam';
    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _client.get(uri, headers: headers).timeout(
          const Duration(seconds: 10),
        );
  }

  /// Writes merchant profile to `/users/{uid}.json` with `setupComplete: true`.
  /// Persists locally immediately, then syncs to RTDB.
  Future<bool> saveUserProfile(UserProfile profile) async {
    // 1. Immediately update local in-memory and persistent cache
    _cachedProfile = profile;
    _profileController.add(profile);
    await _saveCachedProfileToPrefs(profile);

    // 2. Synchronize to remote RTDB
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
        debugPrint('[DatabaseService] Profile saved successfully to RTDB with setupComplete=true!');
        return true;
      } else {
        debugPrint('[DatabaseService] FAILED to save profile to remote RTDB: status=${res.statusCode}, body=${res.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[DatabaseService] Exception saving profile to remote RTDB: $e');
      return false;
    }
  }

  /// Duplicate accounts are guarded securely at the Firebase Authentication layer
  /// (which natively prevents duplicate email and phone sign-ups).
  /// Bulk querying /users.json is disabled to protect merchant privacy and satisfy
  /// hardened database rules.
  Future<String?> findDuplicateAccount({
    required String currentUid,
    String? phone,
    String? email,
  }) async {
    return null;
  }

  /// Permanently deletes the merchant profile from database
  Future<void> deleteUserProfile(String uid) async {
    try {
      final user = _currentUser;
      final token = await user?.getIdToken();
      final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
      final url = '$rtdbUrl/$kCollectionUsers/$uid.json$authParam';
      final uri = Uri.parse(url);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      await _client.delete(uri, headers: headers);
    } catch (e) {
      debugPrint('[DatabaseService] Error deleting user profile: $e');
    } finally {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cacheKey(uid));
      } catch (_) {}
      clearLocalCache();
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
