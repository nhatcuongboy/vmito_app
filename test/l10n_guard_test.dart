import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the "no hardcoded user-facing strings" rule.
///
/// `docs/I18N.md` calls this the most valuable check in the whole port,
/// because hand-translating screens is exactly how Vietnamese literals leak
/// into an English UI — which is precisely what happened to the Apple sign-in
/// button and the court tile before this test existed.
///
/// The signal is Vietnamese diacritics in a Dart string literal. It cannot
/// catch an English literal, but English is also the language a reviewer
/// notices; a stray `'Đang đấu'` renders wrong for two of the three locales
/// and nobody sees it until a user complains.
void main() {
  test('no Vietnamese literals outside l10n and tests', () {
    final offenders = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      if (_isExempt(file.path)) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isComment(line)) continue;

        for (final match in _stringLiteral.allMatches(line)) {
          final literal = match.group(0)!;
          if (!_vietnamese.hasMatch(literal)) continue;
          offenders.add('${file.path}:${i + 1}  $literal');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'User-facing text must come from AppLocalizations. Add a key to '
          'lib/l10n/app_vi.arb (plus en and zh), run `flutter gen-l10n`, and '
          'read it with `AppLocalizations.of(context)`.\n\n'
          '${offenders.join('\n')}',
    );
  });
}

/// Only single-quoted literals; that is the project's style and keeps the
/// pattern simple enough to stay trustworthy.
final _stringLiteral = RegExp(r"'[^'\n]*'");

final _vietnamese = RegExp(
  '[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩị'
  'òóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ'
  'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊ'
  'ÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ]',
);

bool _isComment(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//') || trimmed.startsWith('*');
}

bool _isExempt(String path) {
  // Generated localizations legitimately contain every language.
  if (path.contains('/l10n/')) return true;
  // Generated model/serialization code.
  if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) return true;
  if (path.contains('/api/generated/')) return true;
  // The last-resort messages used when the backend sends nothing usable.
  // These are the documented Vietnamese-default fallbacks, and screens are
  // expected to map ApiErrorKind onto a localized string before display.
  if (path.endsWith('core/network/api_exception.dart')) return true;
  // Locale-parameterised defaults, overridden by every caller that has an
  // AppLocalizations to hand.
  if (path.endsWith('core/utils/formatters.dart')) return true;
  return false;
}

Iterable<File> _dartFilesUnder(String directory) sync* {
  final root = Directory(directory);
  if (!root.existsSync()) return;
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}
