// lib/utils/speech_template_builder.dart
//
// Pure Dart speech template builder for MyUPI Soundbox announcements.
// Ensures 100% parity across Settings preview, Test announcement,
// Onboarding voice sample, and native Android speech.

class SpeechTemplateBuilder {
  // Brand pronunciation map (pronounces letters, never "my-u-pee")
  static const Map<String, String> brandNames = {
    'en-IN': 'My U P I',
    'hi-IN': 'माय यू पी आई',
    'mr-IN': 'माय यू पी आय',
    'gu-IN': 'માય યુ પી આઈ',
    'ta-IN': 'மை யூ பி ஐ',
    'te-IN': 'మై యు పి ఐ',
    'bn-IN': 'মাই ইউ পি আই',
    'kn-IN': 'ಮೈ ಯು ಪಿ ಐ',
  };

  /// Sanitizes merchant shop names for TTS:
  /// - Replaces '&' with 'and'
  /// - Strips emojis and punctuation symbols
  /// - Collapses repeated spaces
  /// - Caps at ~30 characters / 4–5 words at a clean word boundary
  static String sanitizeShopName(String raw) {
    if (raw.trim().isEmpty) return '';

    // 1. Replace '&' with 'and'
    String s = raw.replaceAll('&', ' and ');

    // 2. Strip emojis, punctuation and symbols, keeping Unicode letters, digits, whitespace, hyphen
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s\-]', unicode: true), ' ');

    // 3. Collapse multiple spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';

    // 4. Cap at ~30 characters or 5 words, cutting at a word boundary
    final words = s.split(' ');
    final cappedWords = <String>[];
    int charCount = 0;
    for (final word in words) {
      if (cappedWords.length >= 5) break;
      final addedLen = cappedWords.isEmpty ? word.length : word.length + 1;
      if (charCount + addedLen > 30 && cappedWords.isNotEmpty) break;
      cappedWords.add(word);
      charCount += addedLen;
    }
    return cappedWords.join(' ').trim();
  }

  /// Converts a numeric amount string into localized spoken words.
  /// Always speaks "rupee/rupees", never "Rs." or "₹".
  /// Handles paise when present; omits paise when zero.
  static String formatSpokenAmount(String rawAmount, String langCode) {
    final cleaned = rawAmount.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return '';

    final parts = cleaned.split('.');
    final rupeeInt = int.tryParse(parts[0]) ?? 0;
    final rupeeDisplay = parts[0];
    final paiseStr = parts.length > 1 ? parts[1].padRight(2, '0').substring(0, 2) : null;
    final paiseInt = paiseStr != null ? (int.tryParse(paiseStr) ?? 0) : 0;

    return switch (langCode) {
      'hi-IN' => paiseInt > 0 ? '$rupeeDisplay रुपये $paiseInt पैसे' : '$rupeeDisplay रुपये',
      'mr-IN' => paiseInt > 0 ? '$rupeeDisplay रुपये $paiseInt पैसे' : '$rupeeDisplay रुपये',
      'gu-IN' => paiseInt > 0 ? '$rupeeDisplay રૂપિયા $paiseInt પૈસા' : '$rupeeDisplay રૂપિયા',
      'ta-IN' => paiseInt > 0 ? '$rupeeDisplay ரூபாய் $paiseInt காசுகள்' : '$rupeeDisplay ரூபாய்',
      'te-IN' => paiseInt > 0 ? '$rupeeDisplay రూపాయలు $paiseInt పైసలు' : '$rupeeDisplay రూపాయలు',
      'bn-IN' => paiseInt > 0 ? '$rupeeDisplay টাকা $paiseInt পয়সা' : '$rupeeDisplay টাকা',
      'kn-IN' => paiseInt > 0 ? '$rupeeDisplay ರೂಪಾಯಿ $paiseInt ಪೈಸೆ' : '$rupeeDisplay ರೂಪಾಯಿ',
      _ => () {
        final rupeeWord = rupeeInt == 1 ? 'rupee' : 'rupees';
        return paiseInt > 0 ? '$rupeeDisplay $rupeeWord $paiseInt paise' : '$rupeeDisplay $rupeeWord';
      }(),
    };
  }

  /// Builds the complete announcement sentence.
  /// Formats:
  /// - A (Standard): {amount} rupees received on MyUPI
  /// - B (Short): {amount} rupees received
  /// - C (With Shop): {amount} rupees received on MyUPI for {shop}
  ///
  /// Behaviour:
  /// - When includeShopName is ON and shop name is non-empty, Format A behaves as C.
  /// - Format B never speaks the shop name.
  /// - Falls back cleanly if shop name is empty.
  static String buildAnnouncement({
    required String rawAmount,
    String langCode = 'en-IN',
    String format = 'A',
    String merchantName = '',
    bool includeShopName = false,
  }) {
    final amountText = formatSpokenAmount(rawAmount, langCode);
    if (amountText.isEmpty) return 'Payment received';

    final brand = brandNames[langCode] ?? brandNames['en-IN']!;
    final sanitizedShop = sanitizeShopName(merchantName);
    final hasShop = includeShopName && sanitizedShop.isNotEmpty;

    final effectiveFormat = switch (format.toUpperCase()) {
      'B' => 'B',
      'C' => hasShop ? 'C' : 'A',
      _ => hasShop ? 'C' : 'A',
    };

    return switch (langCode) {
      'hi-IN' => switch (effectiveFormat) {
        'B' => '$amountText प्राप्त हुए',
        'C' => '$brand पर $amountText प्राप्त हुए, $sanitizedShop के लिए',
        _ => '$brand पर $amountText प्राप्त हुए',
      },
      'mr-IN' => switch (effectiveFormat) {
        'B' => '$amountText मिळाले',
        'C' => '$brand वर $amountText मिळाले, $sanitizedShop साठी',
        _ => '$brand वर $amountText मिळाले',
      },
      'gu-IN' => switch (effectiveFormat) {
        'B' => '$amountText પ્રાપ્ત થયા',
        'C' => '$brand પર $amountText પ્રાપ્ત થયા, $sanitizedShop માટે',
        _ => '$brand પર $amountText પ્રાપ્ત થયા',
      },
      'ta-IN' => switch (effectiveFormat) {
        'B' => '$amountText பெறப்பட்டது',
        'C' => '$brand இல் $amountText பெறப்பட்டது, $sanitizedShop க்காக',
        _ => '$brand இல் $amountText பெறப்பட்டது',
      },
      'te-IN' => switch (effectiveFormat) {
        'B' => '$amountText అందాయి',
        'C' => '$brand పై $amountText అందాయి, $sanitizedShop కొరకు',
        _ => '$brand పై $amountText అందాయి',
      },
      'bn-IN' => switch (effectiveFormat) {
        'B' => '$amountText পাওয়া গেছে',
        'C' => '$brand এ $amountText পাওয়া গেছে, $sanitizedShop এর জন্য',
        _ => '$brand এ $amountText পাওয়া গেছে',
      },
      'kn-IN' => switch (effectiveFormat) {
        'B' => '$amountText ಸ್ವೀಕರಿಸಲಾಗಿದೆ',
        'C' => '$brand ನಲ್ಲಿ $amountText ಸ್ವೀಕರಿಸಲಾಗಿದೆ, $sanitizedShop ಗಾಗಿ',
        _ => '$brand ನಲ್ಲಿ $amountText ಸ್ವೀಕರಿಸಲಾಗಿದೆ',
      },
      _ => switch (effectiveFormat) {
        'B' => '$amountText received',
        'C' => '$amountText received on $brand for $sanitizedShop',
        _ => '$amountText received on $brand',
      },
    };
  }

  /// Builds the Settings preview bubble text.
  static String getFormatPreviewText({
    required String format,
    String langCode = 'en-IN',
    String merchantName = '',
    bool includeShopName = false,
  }) {
    return buildAnnouncement(
      rawAmount: '500',
      langCode: langCode,
      format: format,
      merchantName: merchantName,
      includeShopName: includeShopName,
    );
  }

  /// Builds the Test announcement sentence.
  static String buildTestSpeech({
    String langCode = 'en-IN',
    String format = 'A',
    String merchantName = '',
    bool includeShopName = false,
  }) {
    return buildAnnouncement(
      rawAmount: '100',
      langCode: langCode,
      format: format,
      merchantName: merchantName,
      includeShopName: includeShopName,
    );
  }
}
