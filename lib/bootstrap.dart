import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vmito_app/app.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';

/// Composition root: builds every long-lived singleton, restores the session,
/// then hands control to [VmitoApp].
///
/// This is the only place `ProviderScope.overrides` is populated. Adding a
/// dependency means adding it here, not reaching for a service locator.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLogger.error(
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  final tokenStorage = TokenStorage();
  final errorBus = ApiErrorBus();
  final preferences = await SharedPreferences.getInstance();

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
      apiErrorBusProvider.overrideWithValue(errorBus),
      apiClientProvider.overrideWithValue(apiClient),
      localeRepositoryProvider.overrideWithValue(
        SharedPreferencesLocaleRepository(preferences),
      ),
    ],
  );

  // Resolve auth before the first frame so the router never flashes sign-in
  // at a user who is in fact signed in.
  await container.read(authControllerProvider.notifier).restoreSession();
  container
      .read(localeControllerProvider.notifier)
      .restore(
        WidgetsBinding.instance.platformDispatcher.locales,
      );

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
