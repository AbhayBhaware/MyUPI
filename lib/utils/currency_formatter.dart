// lib/utils/currency_formatter.dart
//
// Centralized Indian Currency (INR) Formatter.
// ---------------------------------------------
// Follows standard Indian numbering system:
//   ₹1,000 (Thousand)
//   ₹1,00,000 (Lakh)
//   ₹1,00,00,000 (Crore)

abstract class CurrencyFormatter {
  /// Formats a numeric value or string amount into Indian Rupee representation.
  static String format(dynamic value, {bool includeSymbol = true, bool showDecimalsIfZero = false}) {
    if (value == null) return includeSymbol ? '₹0' : '0';

    double numVal;
    if (value is num) {
      numVal = value.toDouble();
    } else if (value is String) {
      final sanitized = value.replaceAll('₹', '').replaceAll(',', '').trim();
      numVal = double.tryParse(sanitized) ?? 0.0;
    } else {
      numVal = 0.0;
    }

    final isNegative = numVal < 0;
    numVal = numVal.abs();

    final hasFractions = (numVal - numVal.truncateToDouble()).abs() > 0.001;
    final intPart = numVal.truncate();
    final fractionPart = (numVal - intPart).toStringAsFixed(2).substring(2);

    final intStr = intPart.toString();
    String formattedInt;

    if (intStr.length <= 3) {
      formattedInt = intStr;
    } else {
      // Last 3 digits
      final lastThree = intStr.substring(intStr.length - 3);
      final remaining = intStr.substring(0, intStr.length - 3);

      // Remaining digits formatted in pairs of 2
      final pairs = <String>[];
      var index = remaining.length;
      while (index > 0) {
        final start = (index - 2) < 0 ? 0 : index - 2;
        pairs.insert(0, remaining.substring(start, index));
        index = start;
      }

      formattedInt = '${pairs.join(',')},$lastThree';
    }

    final symbol = includeSymbol ? '₹' : '';
    final sign = isNegative ? '-' : '';

    if (hasFractions || showDecimalsIfZero) {
      return '$sign$symbol$formattedInt.$fractionPart';
    } else {
      return '$sign$symbol$formattedInt';
    }
  }

  /// Parses a string into a clean decimal string with max 2 decimals for UPI URI (e.g. "450" or "450.50").
  static String? parseValidUpiAmount(String input) {
    final trimmed = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (trimmed.isEmpty) return null;

    final regex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regex.hasMatch(trimmed)) return null;

    final val = double.tryParse(trimmed);
    if (val == null || val <= 0 || val > 100000.0) return null;

    if (val == val.truncateToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }
}
