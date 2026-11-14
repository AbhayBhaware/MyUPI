// lib/utils/upi_validator.dart
//
// NPCI-Compliant UPI ID (VPA) Validator, App Detector, and Verification Service.
// -------------------------------------------------------------------------------
// Protects merchants against entering incorrect, malformed, or fake UPI IDs.
// Provides live syntactic checks, email domain rejection, app name detection (PhonePe,
// Google Pay, Paytm, BHIM), and 1-tap live verification via installed UPI apps.

import 'package:flutter/foundation.dart';
import '../app_channels.dart';

/// The result of validating a UPI ID string.
class UpiValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? appName;
  final String? providerName;
  final String normalizedUpiId;
  final bool isRecognizedHandle;

  const UpiValidationResult({
    required this.isValid,
    this.errorMessage,
    this.appName,
    this.providerName,
    required this.normalizedUpiId,
    this.isRecognizedHandle = false,
  });

  bool get isHighConfidence => isValid && isRecognizedHandle;
}

class UpiValidator {
  UpiValidator._();

  /// Common email domains that users mistakenly enter instead of a bank UPI handle.
  static const Set<String> _disallowedEmailDomains = {
    'gmail.com',
    'yahoo.com',
    'yahoo.in',
    'yahoo.co.in',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'rediffmail.com',
    'mail.com',
    'proton.me',
    'protonmail.com',
    'zoho.com',
    'aol.com',
    'live.com',
    'msn.com',
  };

  /// Comprehensive registry mapping NPCI PSP handles to their official App / Service name.
  /// Pure App Names ONLY — no bank names or parenthetical details.
  static const Map<String, String> _npciAppRegistry = {
    // ── Google Pay (Tez) ──────────────────────────────────────────────────
    'okhdfcbank': 'Google Pay',
    'okicici': 'Google Pay',
    'oksbi': 'Google Pay',
    'okaxis': 'Google Pay',

    // ── PhonePe ───────────────────────────────────────────────────────────
    'ybl': 'PhonePe',
    'ibl': 'PhonePe',
    'axl': 'PhonePe',

    // ── Paytm ─────────────────────────────────────────────────────────────
    'paytm': 'Paytm',
    'ptyes': 'Paytm',
    'pthdfc': 'Paytm',
    'ptaxis': 'Paytm',
    'ptsbi': 'Paytm',

    // ── BHIM (NPCI) ───────────────────────────────────────────────────────
    'upi': 'BHIM',

    // ── Amazon Pay ────────────────────────────────────────────────────────
    'apl': 'Amazon Pay',
    'rapl': 'Amazon Pay',

    // ── WhatsApp Pay ──────────────────────────────────────────────────────
    'waicici': 'WhatsApp',
    'wahdfcbank': 'WhatsApp',
    'wasbi': 'WhatsApp',
    'waaxis': 'WhatsApp',

    // ── Banking UPI Apps ──────────────────────────────────────────────────
    'sbi': 'SBI',
    'sbiyono': 'SBI YONO',
    'cobar': 'SBI',
    'barodampay': 'Bank of Baroda',
    'pnb': 'PNB',
    'crb': 'PNB',
    'cnrb': 'Canara Bank',
    'canarabank': 'Canara Bank',
    'unionbank': 'Union Bank',
    'unionbankofindia': 'Union Bank',
    'uboi': 'Union Bank',
    'boi': 'Bank of India',
    'centralbank': 'Central Bank',
    'uco': 'UCO Bank',
    'indianbank': 'Indian Bank',
    'indbank': 'Indian Bank',
    'psb': 'Punjab & Sind Bank',
    'mahb': 'Bank of Maharashtra',
    'postbank': 'IPPB',
    'ippb': 'IPPB',
    'hdfcbank': 'HDFC Bank',
    'hdfc': 'HDFC Bank',
    'icici': 'ICICI Bank',
    'imei': 'ICICI iMobile',
    'axisbank': 'Axis Bank',
    'axis': 'Axis Bank',
    'kotak': 'Kotak Bank',
    'kmbl': 'Kotak Bank',
    'indus': 'IndusInd Bank',
    'federal': 'Federal Bank',
    'fbl': 'Federal Bank',
    'idfcbank': 'IDFC FIRST Bank',
    'idfc': 'IDFC FIRST Bank',
    'yesbank': 'Yes Bank',
    'yesbankcbl': 'Yes Bank',
    'rbl': 'RBL Bank',
    'bandhan': 'Bandhan Bank',
    'csb': 'CSB Bank',
    'karurvysya': 'Karur Vysya Bank',
    'kvb': 'Karur Vysya Bank',
    'southbank': 'South Indian Bank',
    'sib': 'South Indian Bank',
    'kbl': 'Karnataka Bank',
    'tmb': 'TMB Bank',
    'dlb': 'Dhanlaxmi Bank',
    'dcb': 'DCB Bank',
    'scb': 'Standard Chartered',
    'hsbc': 'HSBC',
    'citi': 'Citi',
    'dbs': 'DBS',
    'aubank': 'AU Bank',
    'equitas': 'Equitas',
    'ujjivan': 'Ujjivan',
    'fincare': 'Fincare',
    'airtel': 'Airtel Payments Bank',
    'jio': 'Jio Payments Bank',
    'nsdl': 'NSDL Payments Bank',
    'fino': 'Fino Payments Bank',

    // ── Popular Fintech UPI Apps ──────────────────────────────────────────
    'jupiteraxis': 'Jupiter',
    'sliceaxis': 'Slice',
    'cred': 'CRED',
    'navi': 'Navi',
    'freecharge': 'Freecharge',
    'ikwik': 'MobiKwik',
    'timepay': 'TimePay',
    'abpb': 'Aditya Birla',
  };

  /// Returns only the pure App Name (e.g. 'PhonePe', 'Google Pay', 'Paytm', 'BHIM').
  /// Does NOT include any bank name or parenthetical details.
  static String? getAppName(String upiId) {
    final trimmed = upiId.trim().toLowerCase();
    if (!trimmed.contains('@')) return null;
    final parts = trimmed.split('@');
    if (parts.length != 2) return null;
    final handle = parts[1];
    return _npciAppRegistry[handle];
  }

  /// Alias for getAppName for backwards compatibility.
  static String? getProviderName(String upiId) => getAppName(upiId);

  /// Validates a raw UPI ID string according to strict NPCI standards.
  /// Returns a detailed [UpiValidationResult].
  static UpiValidationResult validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const UpiValidationResult(
        isValid: false,
        errorMessage: 'UPI ID cannot be empty.',
        normalizedUpiId: '',
      );
    }

    final trimmed = raw.trim().toLowerCase();

    // 1. Whitespace check
    if (trimmed.contains(' ') || trimmed.contains('\t') || trimmed.contains('\n')) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: 'UPI ID cannot contain spaces.',
        normalizedUpiId: trimmed,
      );
    }

    // 2. Check '@' count
    final atCount = '@'.allMatches(trimmed).length;
    if (atCount == 0) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: "UPI ID must contain '@' (e.g. name@okhdfcbank or 9876543210@ybl).",
        normalizedUpiId: trimmed,
      );
    }
    if (atCount > 1) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: "UPI ID can contain only one '@' symbol.",
        normalizedUpiId: trimmed,
      );
    }

    final parts = trimmed.split('@');
    final prefix = parts[0];
    final handle = parts[1];

    // 3. Email Address Prevention
    if (_disallowedEmailDomains.contains(handle) ||
        handle.endsWith('.com') ||
        handle.endsWith('.in') ||
        handle.endsWith('.net') ||
        handle.endsWith('.org')) {
      return UpiValidationResult(
        isValid: false,
        errorMessage:
            "Email addresses (like @$handle) are NOT UPI IDs. Enter your UPI ID (e.g. @ybl, @okhdfcbank, @paytm).",
        normalizedUpiId: trimmed,
      );
    }

    // 4. Prefix Validation (Length 1-50, alphanumeric and . - _)
    if (prefix.isEmpty) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: 'Please enter your username or mobile number before "@".',
        normalizedUpiId: trimmed,
      );
    }
    if (prefix.length > 50) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: 'UPI ID username is too long (maximum 50 characters).',
        normalizedUpiId: trimmed,
      );
    }

    final prefixRegex = RegExp(r'^[a-z0-9]+([.\-_][a-z0-9]+)*$');
    if (!prefixRegex.hasMatch(prefix)) {
      return UpiValidationResult(
        isValid: false,
        errorMessage:
            'Username can only contain letters, numbers, and single dots/hyphens.',
        normalizedUpiId: trimmed,
      );
    }

    // 4b. Mobile Number Check (if prefix is purely 10 digits)
    if (RegExp(r'^\d{10}$').hasMatch(prefix)) {
      final firstDigit = prefix[0];
      if (!['6', '7', '8', '9'].contains(firstDigit)) {
        return UpiValidationResult(
          isValid: false,
          errorMessage: '10-digit mobile number must start with 6, 7, 8, or 9.',
          normalizedUpiId: trimmed,
        );
      }
    }

    // 5. Handle Validation (Length 2-30, letters and digits only)
    if (handle.isEmpty) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: 'Please enter the UPI handle after "@" (e.g. @ybl, @paytm).',
        normalizedUpiId: trimmed,
      );
    }
    if (handle.length < 2) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: 'UPI handle after @ is too short.',
        normalizedUpiId: trimmed,
      );
    }
    if (handle.length > 30) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: 'UPI handle after @ is too long.',
        normalizedUpiId: trimmed,
      );
    }

    final handleRegex = RegExp(r'^[a-z0-9]+$');
    if (!handleRegex.hasMatch(handle)) {
      return UpiValidationResult(
        isValid: false,
        errorMessage: "UPI handle after '@' can only contain letters and numbers.",
        normalizedUpiId: trimmed,
      );
    }

    // 6. App Registry Match (Pure App Name)
    final appName = _npciAppRegistry[handle];
    if (appName != null) {
      return UpiValidationResult(
        isValid: true,
        errorMessage: null,
        appName: appName,
        providerName: appName,
        normalizedUpiId: trimmed,
        isRecognizedHandle: true,
      );
    }

    // Syntactically valid custom handle
    return UpiValidationResult(
      isValid: true,
      errorMessage: null,
      appName: 'UPI App',
      providerName: 'UPI App',
      normalizedUpiId: trimmed,
      isRecognizedHandle: false,
    );
  }

  /// Launches an installed UPI app with a ₹1 test payment intent.
  static Future<bool> launchUpiTestPayment({
    required String upiId,
    required String merchantName,
    double amount = 1.0,
  }) async {
    final trimmed = upiId.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    final encodedName = Uri.encodeComponent(
      merchantName.trim().isEmpty ? 'Merchant Test' : merchantName.trim(),
    );
    final uri = 'upi://pay?pa=$trimmed&pn=$encodedName&am=${amount.toStringAsFixed(0)}&cu=INR';

    try {
      final success = await kMethodChannel.invokeMethod<bool>('openUrl', {'url': uri});
      return success ?? false;
    } catch (e) {
      debugPrint('[UpiValidator] Failed to launch UPI test intent: $e');
      return false;
    }
  }
}
