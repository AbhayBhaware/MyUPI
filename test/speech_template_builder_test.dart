// test/speech_template_builder_test.dart
//
// Unit tests for SpeechTemplateBuilder ensuring 100% template parity
// across amounts, languages, formats, and shop name sanitization.

import 'package:flutter_test/flutter_test.dart';
import 'package:myupi/utils/speech_template_builder.dart';

void main() {
  group('SpeechTemplateBuilder — Shop Name Sanitization', () {
    test('Empty and whitespace inputs return empty string', () {
      expect(SpeechTemplateBuilder.sanitizeShopName(''), '');
      expect(SpeechTemplateBuilder.sanitizeShopName('   '), '');
    });

    test('Replaces ampersand with and', () {
      expect(
        SpeechTemplateBuilder.sanitizeShopName('A & B Stores'),
        'A and B Stores',
      );
    });

    test('Strips emojis and unwanted punctuation symbols', () {
      expect(
        SpeechTemplateBuilder.sanitizeShopName('Ganesh Sweets 🍰 & Bakery 🌟*#_!'),
        'Ganesh Sweets and Bakery',
      );
    });

    test('Preserves numeric digits', () {
      expect(
        SpeechTemplateBuilder.sanitizeShopName('11 11 Studios'),
        '11 11 Studios',
      );
    });

    test('Caps at word boundary within ~30 chars / 5 words', () {
      final longName = 'Super Grand Luxury Mega Store of Electronics and Groceries';
      final sanitized = SpeechTemplateBuilder.sanitizeShopName(longName);
      // Capped to at most 5 words and <= 30 chars
      expect(sanitized.split(' ').length, lessThanOrEqualTo(5));
      expect(sanitized.length, lessThanOrEqualTo(30));
      expect(sanitized, 'Super Grand Luxury Mega Store');
    });
  });

  group('SpeechTemplateBuilder — Amounts and Currency Formatting', () {
    test('English singular 1 rupee vs plural rupees', () {
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('1', 'en-IN'),
        '1 rupee',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('7', 'en-IN'),
        '7 rupees',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('100', 'en-IN'),
        '100 rupees',
      );
    });

    test('English amounts with paise', () {
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('250.50', 'en-IN'),
        '250 rupees 50 paise',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('1.25', 'en-IN'),
        '1 rupee 25 paise',
      );
    });

    test('Indian language amounts', () {
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('500', 'hi-IN'),
        '500 रुपये',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('250.50', 'hi-IN'),
        '250 रुपये 50 पैसे',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('500', 'mr-IN'),
        '500 रुपये',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('500', 'gu-IN'),
        '500 રૂપિયા',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('500', 'ta-IN'),
        '500 ரூபாய்',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('500', 'te-IN'),
        '500 రూపాయలు',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('500', 'bn-IN'),
        '500 টাকা',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('500', 'kn-IN'),
        '500 ರೂಪಾಯಿ',
      );
    });

    test('Amounts with commas are cleaned properly', () {
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('1,000', 'en-IN'),
        '1000 rupees',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('12,345', 'en-IN'),
        '12345 rupees',
      );
      expect(
        SpeechTemplateBuilder.formatSpokenAmount('1,00,000', 'en-IN'),
        '100000 rupees',
      );
    });
  });

  group('SpeechTemplateBuilder — Announcement Templates Across Formats & Languages', () {
    const testAmounts = ['1', '7', '11', '99', '100', '250.50', '1,000', '12,345', '1,00,000'];
    const languages = ['en-IN', 'hi-IN', 'mr-IN', 'gu-IN', 'ta-IN', 'te-IN', 'bn-IN', 'kn-IN'];

    test('English (en-IN) Formats A, B, C with shop name', () {
      final a = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'en-IN',
        format: 'A',
      );
      expect(a, '500 rupees received on My U P I');

      final b = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'en-IN',
        format: 'B',
      );
      expect(b, '500 rupees received');

      final c = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'en-IN',
        format: 'C',
        merchantName: 'Ramesh Kirana Store',
        includeShopName: true,
      );
      expect(c, '500 rupees received on My U P I for Ramesh Kirana Store');

      // When includeShopName is ON, Format A behaves as C
      final aWithShop = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'en-IN',
        format: 'A',
        merchantName: 'Ramesh Kirana Store',
        includeShopName: true,
      );
      expect(aWithShop, '500 rupees received on My U P I for Ramesh Kirana Store');

      // Format B never speaks shop name even when includeShopName is ON
      final bWithShop = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'en-IN',
        format: 'B',
        merchantName: 'Ramesh Kirana Store',
        includeShopName: true,
      );
      expect(bWithShop, '500 rupees received');

      // Clean fallback if shop name is empty
      final cEmpty = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'en-IN',
        format: 'C',
        merchantName: '',
        includeShopName: true,
      );
      expect(cEmpty, '500 rupees received on My U P I');
    });

    test('Hindi (hi-IN) Formats A, B, C', () {
      final a = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'hi-IN',
        format: 'A',
      );
      expect(a, 'माय यू पी आई पर 500 रुपये प्राप्त हुए');

      final b = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'hi-IN',
        format: 'B',
      );
      expect(b, '500 रुपये प्राप्त हुए');

      final c = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'hi-IN',
        format: 'C',
        merchantName: 'Ramesh Store',
        includeShopName: true,
      );
      expect(c, 'माय यू पी आई पर 500 रुपये प्राप्त हुए, Ramesh Store के लिए');
    });

    test('Marathi (mr-IN) Formats A, B, C', () {
      final a = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'mr-IN',
        format: 'A',
      );
      expect(a, 'माय यू पी आय वर 500 रुपये मिळाले');

      final b = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'mr-IN',
        format: 'B',
      );
      expect(b, '500 रुपये मिळाले');

      final c = SpeechTemplateBuilder.buildAnnouncement(
        rawAmount: '500',
        langCode: 'mr-IN',
        format: 'C',
        merchantName: 'Ramesh Store',
        includeShopName: true,
      );
      expect(c, 'माय यू पी आय वर 500 रुपये मिळाले, Ramesh Store साठी');
    });

    test('Matrix validation: All amounts × All languages execute without error', () {
      for (final lang in languages) {
        for (final amt in testAmounts) {
          for (final fmt in ['A', 'B', 'C']) {
            final speech = SpeechTemplateBuilder.buildAnnouncement(
              rawAmount: amt,
              langCode: lang,
              format: fmt,
              merchantName: 'Ramesh Store',
              includeShopName: true,
            );
            expect(speech.isNotEmpty, isTrue);
            expect(speech.contains('Rs.'), isFalse);
            expect(speech.contains('₹'), isFalse);
          }
        }
      }
    });
  });
}
