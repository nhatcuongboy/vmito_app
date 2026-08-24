import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Groups digits as the user types: `50000` → `50.000`.
///
/// Money is integer VND with no minor units, so this strips everything that is
/// not a digit rather than trying to parse a decimal. Grouping uses the
/// `vi_VN` pattern (a dot), matching `Money.vndPlain` on the read side — a
/// field that formats with commas and renders back with dots reads as a bug.
///
/// The selection is recomputed from the **digit count to the left of the
/// caret**, not from the raw offset. Inserting a separator shifts every offset
/// after it by one, and a naive `TextSelection.collapsed(offset: text.length)`
/// is why so many money fields jump the caret to the end mid-edit.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  ThousandsSeparatorFormatter();

  static final RegExp _nonDigit = RegExp('[^0-9]');

  final NumberFormat _format = NumberFormat.decimalPattern('vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    // Leading zeros are never meaningful in a price and confuse the parse.
    final value = int.tryParse(digits);
    if (value == null) return oldValue;

    final formatted = _format.format(value);
    final digitsBeforeCaret = newValue.text
        .substring(
          0,
          newValue.selection.baseOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(_nonDigit, '')
        .length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetAfterDigits(formatted, digitsBeforeCaret),
      ),
    );
  }

  static int _offsetAfterDigits(String text, int digitCount) {
    if (digitCount <= 0) return 0;
    var seen = 0;
    for (var index = 0; index < text.length; index++) {
      if (_isDigit(text.codeUnitAt(index))) {
        seen++;
        if (seen == digitCount) return index + 1;
      }
    }
    return text.length;
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  /// Reads a grouped string back to an int. Empty means "not set", which is
  /// different from zero — a fee of 0 is free, no fee at all is unpriced.
  static int? parse(String text) {
    final digits = text.replaceAll(_nonDigit, '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  /// Formats an int for seeding a controller from existing state.
  static String display(int? value) =>
      value == null ? '' : NumberFormat.decimalPattern('vi_VN').format(value);
}

/// Clamps a whole-number field to `[min, max]` while it is being typed.
///
/// Rejects the keystroke rather than silently clamping the value: a host
/// typing `12` into a 2–12 field would otherwise see `1` snap to `2` after the
/// first digit and end up with `22`.
class IntRangeFormatter extends TextInputFormatter {
  const IntRangeFormatter(this.min, this.max);

  final int min;
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final value = int.tryParse(newValue.text);
    if (value == null) return oldValue;
    // Only the upper bound can be checked mid-typing — `1` on the way to `12`
    // is below a min of 2 and must still be allowed.
    return value > max ? oldValue : newValue;
  }
}
