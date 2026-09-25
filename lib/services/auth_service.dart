// lib/services/auth_service.dart
//
// Unified Authentication Service for MyUPI.
// ------------------------------------------
// Implements the single auth flow principle:
// 1. Google Sign-In (single tap).
// 2. Phone OTP (verification + auto-advance 6-digit input + resend countdown).
// 3. Email Auth (login or account creation).
// 4. Clean Sign-Out clearing local cached state and session.
// 5. Safe uninitialized-Firebase guards for unit testing environments.

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firestore_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? Stream<User?>.value(null);

  User? get currentUser => _auth?.currentUser;

  // ─── Google Sign-In (Native Mobile Flow) ───────────────────────────────────

  /// Signs in using native GoogleSignIn account picker + Firebase credential.
  /// Returns User on success, null on user dismiss/cancellation.
  Future<User?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw FirebaseAuthException(
        code: 'not-initialized',
        message: 'Firebase is not initialized.',
      );
    }

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the native Google account picker sheet
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await auth.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException on Google Sign-In: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In error: $e');
      rethrow;
    }
  }

  // ─── Phone OTP ─────────────────────────────────────────────────────────────

  /// Initiates Phone Number verification via Firebase Auth.
  Future<void> sendPhoneOtp({
    required String rawPhone,
    int? resendToken,
    required void Function(String verificationId, int? newResendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    final auth = _auth;
    if (auth == null) {
      onError('Firebase is not initialized on this device.');
      return;
    }

    try {
      // Normalize to E.164 Indian phone format (+91)
      String cleaned = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (cleaned.startsWith('91') && cleaned.length == 12) {
        cleaned = '+$cleaned';
      } else if (cleaned.length == 10) {
        cleaned = '+91$cleaned';
      } else if (!cleaned.startsWith('+')) {
        cleaned = '+$cleaned';
      }

      await auth.verifyPhoneNumber(
        phoneNumber: cleaned,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (onAutoVerified != null) {
            onAutoVerified(credential);
          } else {
            await auth.signInWithCredential(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[AuthService] verifyPhoneNumber failed: ${e.code} ${e.message}');
          String message = 'Failed to send OTP. Please try again.';
          if (e.code == 'too-many-requests') {
            message = 'Too many requests. Please wait a few minutes before trying again.';
          } else if (e.code == 'invalid-phone-number') {
            message = 'The entered mobile number is invalid.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Please use Email or Google to sign in.';
          } else if (e.message != null && e.message!.isNotEmpty) {
            message = e.message!;
          }
          onError(message);
        },
        codeSent: (String verificationId, int? token) {
          onCodeSent(verificationId, token);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto retrieval timed out
        },
      );
    } catch (e) {
      onError('An error occurred while sending OTP: $e');
    }
  }

  /// Verifies the entered 6-digit OTP code.
  Future<User?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final auth = _auth;
    if (auth == null) return null;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final userCredential = await auth.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] verifyOtp failed: ${e.code} ${e.message}');
      rethrow;
    }
  }

  // ─── Email & Password ──────────────────────────────────────────────────────

  /// Logs in with email & password.
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw FirebaseAuthException(
        code: 'not-initialized',
        message: 'Firebase is not initialized.',
      );
    }

    try {
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Creates a new user account with email & password.
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw FirebaseAuthException(
        code: 'not-initialized',
        message: 'Firebase is not initialized.',
      );
    }

    try {
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Sends password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) return;
    await auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  // ─── Sign Out & Local State Clean Up ───────────────────────────────────────

  /// Clean sign-out: signs out of Firebase Auth, Google, and wipes local caches.
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await _auth?.signOut();
    } catch (_) {}
    FirestoreService.instance.clearLocalCache();
  }
}
