import 'package:flutter/services.dart';

/// Shared numeric keyboards + formatters for money and qty fields.
abstract final class NumericInput {
  static const moneyKeyboard = TextInputType.numberWithOptions(decimal: true);
  static const integerKeyboard = TextInputType.number;

  /// Digits with at most one decimal point (up to [decimalPlaces] after the point).
  static List<TextInputFormatter> money({int decimalPlaces = 2}) => [
        _SingleDecimalFormatter(decimalPlaces: decimalPlaces),
      ];

  /// Digits only (stock counts, integer qty).
  static List<TextInputFormatter> get integers => [
        FilteringTextInputFormatter.digitsOnly,
      ];

  static double? tryParseMoney(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  static int? tryParseInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }
}

class _SingleDecimalFormatter extends TextInputFormatter {
  _SingleDecimalFormatter({this.decimalPlaces = 2});

  final int decimalPlaces;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final pattern = RegExp('^\\d*\\.?\\d{0,$decimalPlaces}\$');
    if (pattern.hasMatch(text)) return newValue;
    return oldValue;
  }
}
