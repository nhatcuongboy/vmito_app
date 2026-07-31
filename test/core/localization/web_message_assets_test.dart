import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Map<String, dynamic> _readBundle(String fileName) =>
    jsonDecode(
          File('assets/i18n/web/$fileName').readAsStringSync(),
        )
        as Map<String, dynamic>;

int _scalarCount(Object? value) => switch (value) {
  final Map<dynamic, dynamic> map => map.values.fold(
    0,
    (count, child) => count + _scalarCount(child),
  ),
  final List<dynamic> list => list.fold(
    0,
    (count, child) => count + _scalarCount(child),
  ),
  _ => 1,
};

String _value(Map<String, dynamic> bundle, String path) {
  Object? current = bundle;
  for (final segment in path.split('.')) {
    current = (current! as Map<String, dynamic>)[segment];
  }
  return current! as String;
}

void main() {
  test('contains complete vi, en, and cn web dictionaries', () {
    for (final fileName in ['vi.json', 'en.json', 'cn.json']) {
      final bundle = _readBundle(fileName);
      expect(_scalarCount(bundle), greaterThan(6000), reason: fileName);
      expect(_value(bundle, 'common.appName'), 'Vmito');
    }
  });

  test('mobile facade uses canonical web copy for mapped messages', () async {
    final cases = <(Locale, String)>[
      (const Locale('vi'), 'vi.json'),
      (const Locale('en'), 'en.json'),
      (const Locale('zh'), 'cn.json'),
    ];

    for (final (locale, fileName) in cases) {
      final bundle = _readBundle(fileName);
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.commonCancel, _value(bundle, 'common.cancel'));
      expect(l10n.authSignIn, _value(bundle, 'auth.signin.signInButton'));
      expect(l10n.navHome, _value(bundle, 'navigation.mainHome'));
      expect(l10n.sessionDetailTitle, _value(bundle, 'session.sessionDetails'));
      expect(l10n.level1, _value(bundle, 'common.levelShorts.1'));
    }
  });
}
