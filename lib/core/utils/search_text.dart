/// Accent-insensitive matching for Vietnamese search text.
///
/// Users type without diacritics ("quang hung") while names are stored with
/// them ("Quang Hưng"), so plain `contains` misses almost every real match.
/// Folding works one UTF-16 unit at a time and records where each folded unit
/// came from, so a match found in the folded text maps back to exact offsets
/// in the original for highlighting.
library;

const _accentGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _foldMap = {
  for (final group in _accentGroups.entries)
    for (final char in group.value.split('')) char: group.key,
};

bool _isCombiningMark(int unit) => unit >= 0x0300 && unit <= 0x036F;

({String folded, List<int> origins}) _fold(String text) {
  final buffer = StringBuffer();
  final origins = <int>[];
  for (var index = 0; index < text.length; index++) {
    final unit = text.codeUnitAt(index);
    // NFD input (decomposed accents) folds to the same base letters as NFC.
    if (_isCombiningMark(unit)) continue;
    final original = String.fromCharCode(unit);
    final lower = original.toLowerCase();
    // A few non-Vietnamese letters lowercase to two units; keeping them as-is
    // preserves the one-unit-in, one-unit-out index mapping.
    buffer.write(lower.length == 1 ? _foldMap[lower] ?? lower : original);
    origins.add(index);
  }
  return (folded: buffer.toString(), origins: origins);
}

/// Lowercase, accent-free form of [text] for comparisons.
String foldSearchText(String text) => _fold(text).folded;

/// Where [query] first occurs in [text], ignoring case and accents.
///
/// Offsets index into the original [text]. Null when [query] is blank or
/// absent.
({int start, int end})? searchMatchRange(String text, String query) {
  final needle = foldSearchText(query.trim());
  if (needle.isEmpty) return null;
  final haystack = _fold(text);
  final at = haystack.folded.indexOf(needle);
  if (at < 0) return null;
  var end = haystack.origins[at + needle.length - 1] + 1;
  // Keep trailing combining marks with the last matched letter.
  while (end < text.length && _isCombiningMark(text.codeUnitAt(end))) {
    end++;
  }
  return (start: haystack.origins[at], end: end);
}

/// Whether [text] contains [part], ignoring case and accents.
bool containsSearchText(String text, String part) =>
    searchMatchRange(text, part) != null;
