import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vmito_app/app.dart';
import 'package:vmito_app/core/device/installation_id_store.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/notifications/firebase_bootstrap.dart';
import 'package:vmito_app/core/notifications/push_registration_manager.dart';
import 'package:vmito_app/core/security/app_lock_controller.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/court/application/court_display_mode_controller.dart';
import 'package:vmito_app/features/home/application/home_search_history.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_search_history.dart';

/// Composition root: builds every long-lived singleton, restores the session,
/// then hands control to [VmitoApp].
///
/// This is the only place `ProviderScope.overrides` is populated. Adding a
/// dependency means adding it here, not reaching for a service locator.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseForPush();

  FlutterError.onError = (details) {
    AppLogger.error(
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  final tokenStorage = TokenStorage();
  final biometricLockStorage = BiometricLockStorage();
  final errorBus = ApiErrorBus();
  final preferences = await SharedPreferences.getInstance();

  await tokenStorage.hydrate();
  var biometricLockEnabled = await biometricLockStorage.readEnabled();
  if (biometricLockEnabled &&
      !tokenStorage.hasAccessToken &&
      await biometricLockStorage.readAccount() == null) {
    // A crash between clearing tokens and clearing this flag must not make the
    // next account inherit the previous account's security preference. A saved
    // account record is the legitimate no-access-token case: the user signed
    // out with biometric sign-in armed.
    await biometricLockStorage.clear();
    biometricLockEnabled = false;
  }
  final shouldLockSavedSession =
      biometricLockEnabled && tokenStorage.hasAccessToken;

  // The interceptor needs to sign the user out on a failed refresh, but the
  // container does not exist yet — this late binding closes the cycle.
  late final ProviderContainer container;

  final apiClient = buildApiClient(
    tokenStorage: tokenStorage,
    errorBus: errorBus,
    onSessionExpired: () =>
        container.read(authControllerProvider.notifier).handleSessionExpired(),
  );

  container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokenStorage),
      biometricLockStorageProvider.overrideWithValue(biometricLockStorage),
      apiErrorBusProvider.overrideWithValue(errorBus),
      apiClientProvider.overrideWithValue(apiClient),
      installationIdStoreProvider.overrideWithValue(
        InstallationIdStore(preferences),
      ),
      sessionCleanupProvider.overrideWithValue(
        ({unregisterServer = true}) async {
          await container
              .read(pushRegistrationManagerProvider)
              ?.unregister(unregisterServer: unregisterServer);
        },
      ),
      localeRepositoryProvider.overrideWithValue(
        SharedPreferencesLocaleRepository(preferences),
      ),
      themeRepositoryProvider.overrideWithValue(
        SharedPreferencesThemeRepository(preferences),
      ),
      locationPreferencesRepositoryProvider.overrideWithValue(
        SharedPreferencesLocationPreferencesRepository(preferences),
      ),
      courtDisplayModeRepositoryProvider.overrideWithValue(
        SharedPreferencesCourtDisplayModeRepository(preferences),
      ),
      homeSearchHistoryRepositoryProvider.overrideWithValue(
        SharedPreferencesHomeSearchHistoryRepository(preferences),
      ),
      mySessionsSearchHistoryRepositoryProvider.overrideWithValue(
        SharedPreferencesMySessionsSearchHistoryRepository(preferences),
      ),
    ],
  );

  container
      .read(appLockControllerProvider.notifier)
      .bootstrap(
        enabled: biometricLockEnabled,
        hasSession: tokenStorage.hasAccessToken,
      );

  // Resolve auth before the first frame so the router never flashes sign-in
  // at a user who is in fact signed in.
  // A protected saved session is the exception: the root lock gate is mounted
  // first, and only restores `/users/me` after device authentication succeeds.
  if (!shouldLockSavedSession) {
    await container.read(authControllerProvider.notifier).restoreSession();
  }
  container
      .read(localeControllerProvider.notifier)
      .restore(
        WidgetsBinding.instance.platformDispatcher.locales,
      );
  container.read(themeModeControllerProvider.notifier).restore();
  container.read(locationPreferencesControllerProvider.notifier).restore();

  runApp(
    UncontrolledProviderScope(container: container, child: const VmitoApp()),
  );
}

/// Catches anything the framework's own handler misses.
///
/// The zone owns the app for its whole lifetime, so the future is intentionally
/// not awaited — `main` returns immediately and the zone keeps running.
void runGuarded(Future<void> Function() body) {
  unawaited(
    runZonedGuarded(
      body,
      (error, stack) =>
          AppLogger.error('uncaught', error: error, stackTrace: stack),
    ),
  );
}
