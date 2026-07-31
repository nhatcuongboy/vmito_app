import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the language selected inside the app.
///
/// Absence of this key means the user has not made a choice yet, so startup
/// resolves the first supported language from the device preferences.
abstract interface class LocaleRepository {
  String? readLanguageCode();

  Future<void> writeLanguageCode(String languageCode);
}

class SharedPreferencesLocaleRepository implements LocaleRepository {
  const SharedPreferencesLocaleRepository(this._preferences);

  final SharedPreferences _preferences;

  static const _languageCodeKey = 'vmito.language_code';

  @override
  String? readLanguageCode() => _preferences.getString(_languageCodeKey);

  @override
  Future<void> writeLanguageCode(String languageCode) async {
    await _preferences.setString(_languageCodeKey, languageCode);
  }
}

final localeRepositoryProvider = Provider<LocaleRepository>(
  (ref) => throw StateError('LocaleRepository must be overridden at startup'),
);

class LocaleController extends Notifier<Locale> {
  static const fallbackLocale = Locale('vi');
  static const supportedLanguageCodes = {'vi', 'en', 'zh'};

  @override
  Locale build() => fallbackLocale;

  LocaleRepository get _repository => ref.read(localeRepositoryProvider);

  /// Restores an explicit choice or resolves the first supported device
  /// locale. If neither source is supported, Vietnamese is used.
  void restore(Iterable<Locale> preferredLocales) {
    final savedCode = _repository.readLanguageCode();
    if (savedCode != null && supportedLanguageCodes.contains(savedCode)) {
      state = Locale(savedCode);
      return;
    }

    state = resolveDeviceLocale(preferredLocales);
  }

  Future<void> select(Locale locale) async {
    if (!supportedLanguageCodes.contains(locale.languageCode)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported locale');
    }

    final normalized = Locale(locale.languageCode);
    state = normalized;
    await _repository.writeLanguageCode(normalized.languageCode);
  }

  static Locale resolveDeviceLocale(Iterable<Locale> preferredLocales) {
    for (final locale in preferredLocales) {
      if (supportedLanguageCodes.contains(locale.languageCode)) {
        return Locale(locale.languageCode);
      }
    }
    return fallbackLocale;
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
