// lib/screens/settings/settings_values.dart
//
// Pure sanitizer and default fallbacks for MyUPI Settings.
// Guarantees that any native return or unexpected input (e.g. 'en-US', 'hi', null, 'fast ')
// is safely sanitized into an allowed domain value before reaching the UI.

const Map<String, String> kLanguages = <String, String>{
  'en-IN': 'English',
  'hi-IN': 'हिन्दी · Hindi',
  'mr-IN': 'मराठी · Marathi',
  'gu-IN': 'ગુજરાતી · Gujarati',
  'ta-IN': 'தமிழ் · Tamil',
  'te-IN': 'తెలుగు · Telugu',
  'bn-IN': 'বাংলা · Bengali',
  'kn-IN': 'ಕನ್ನಡ · Kannada',
};

/// Normalizes any language code (e.g. 'en_US', 'en-US', 'hi', 'HI-IN', 'es') into one of
/// the 8 supported Indic language codes, defaulting to 'en-IN'.
String safeLanguage(String? v) {
  final x = (v ?? '').trim().replaceAll('_', '-');
  if (kLanguages.containsKey(x)) return x;
  // Case-insensitive match
  for (final key in kLanguages.keys) {
    if (key.toLowerCase() == x.toLowerCase()) return key;
  }
  final short = x.split('-').first.toLowerCase();
  return kLanguages.keys.firstWhere(
    (k) => k.toLowerCase().startsWith('$short-'),
    orElse: () => 'en-IN',
  );
}

/// Validates speech pacing: must be 'slow', 'normal', or 'fast'. Defaults to 'normal'.
String safeSpeed(String? v) {
  final clean = (v ?? '').trim().toLowerCase();
  return const {'slow', 'normal', 'fast'}.contains(clean) ? clean : 'normal';
}

/// Validates announcement format code: 'A' (Standard), 'B' (Short), 'C' (With shop name).
/// Defaults to 'A'.
String safeFormat(String? v) {
  final clean = (v ?? '').trim().toUpperCase();
  return const {'A', 'B', 'C'}.contains(clean) ? clean : 'A';
}

/// Sanitizes merchant name fallback. Defaults to 'MyUPI'.
String safeMerchantName(String? v) {
  final clean = (v ?? '').trim();
  return clean.isEmpty ? 'MyUPI' : clean;
}
