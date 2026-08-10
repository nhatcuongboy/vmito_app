import 'dart:ui';

/// Parses a CSS hex colour the web stores, e.g. `#179a3b`.
///
/// Returns null for anything unparseable so a bad value falls back to the
/// built-in court colour instead of throwing on a host's board.
Color? parseHexColor(String? value) {
  final hex = value?.trim().replaceFirst('#', '');
  if (hex == null) return null;
  final normalised = switch (hex.length) {
    6 => 'ff$hex',
    8 => hex,
    // `#abc` shorthand: expand each nibble.
    3 => 'ff${hex.split('').map((c) => '$c$c').join()}',
    _ => null,
  };
  if (normalised == null) return null;
  final parsed = int.tryParse(normalised, radix: 16);
  return parsed == null ? null : Color(parsed);
}
