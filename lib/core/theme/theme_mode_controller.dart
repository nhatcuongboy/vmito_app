import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the theme mode selected inside the app.
///
/// Absence of this key means the user has not made a choice yet, which is a
/// no-op: [ThemeMode.system] is already the built-in default and tracks the
/// device setting on its own.
abstract interface class ThemeRepository {
  String? readThemeModeName();

  Future<void> writeThemeModeName(String themeModeName);
}

class SharedPreferencesThemeRepository implements ThemeRepository {
  const SharedPreferencesThemeRepository(this._preferences);

  final SharedPreferences _preferences;

  static const _themeModeKey = 'vmito.theme_mode';

  @override
  String? readThemeModeName() => _preferences.getString(_themeModeKey);

  @override
  Future<void> writeThemeModeName(String themeModeName) async {
    await _preferences.setString(_themeModeKey, themeModeName);
  }
}

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => throw StateError('ThemeRepository must be overridden at startup'),
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  ThemeRepository get _repository => ref.read(themeRepositoryProvider);

  /// Restores an explicit choice, if any. Unlike locale restoration there is
  /// no device signal to resolve against: [ThemeMode.system] already tracks
  /// the OS setting, so a missing or unrecognised preference is a no-op.
  void restore() {
    final savedName = _repository.readThemeModeName();
    if (savedName == null) return;

    for (final mode in ThemeMode.values) {
      if (mode.name == savedName) {
        state = mode;
        return;
      }
    }
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await _repository.writeThemeModeName(mode.name);
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
