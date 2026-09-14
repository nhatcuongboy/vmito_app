import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which welcome-popup version the user has already dismissed, so
/// it shows once per version rather than on every app open.
abstract interface class WelcomePopupPreferences {
  Future<String?> readDismissedToken();
  Future<void> writeDismissedToken(String token);
}

class SharedPreferencesWelcomePopupPreferences
    implements WelcomePopupPreferences {
  SharedPreferencesWelcomePopupPreferences([SharedPreferencesAsync? store])
    : _store = store ?? SharedPreferencesAsync();

  static const dismissedTokenKey = 'vmito.welcomePopup.dismissedToken';
  final SharedPreferencesAsync _store;

  @override
  Future<String?> readDismissedToken() => _store.getString(dismissedTokenKey);

  @override
  Future<void> writeDismissedToken(String token) =>
      _store.setString(dismissedTokenKey, token);
}

final welcomePopupPreferencesProvider = Provider<WelcomePopupPreferences>(
  (ref) => SharedPreferencesWelcomePopupPreferences(),
);
