import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vmito_app/core/device/installation_id_store.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/notification/data/notification_service.dart';

bool get supportsNativePushNotifications =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class PushRegistrationManager {
  PushRegistrationManager(
    this._messaging,
    this._service,
    this._installationIds,
    this._locale,
  );

  final FirebaseMessaging _messaging;
  final NotificationService _service;
  final InstallationIdStore _installationIds;
  final String Function() _locale;

  String? _registeredToken;

  Future<void> sync() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      AppLogger.info('push permission not granted');
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS &&
        !await _waitForApnsToken()) {
      AppLogger.warn(
        'APNs token was not available; push registration deferred',
      );
      return;
    }

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) await registerToken(token);
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await _messaging.getAPNSToken() != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return false;
  }

  Future<void> registerToken(String token) async {
    if (_registeredToken == token) return;
    final package = await PackageInfo.fromPlatform();
    await _service.registerDevice(
      token: token,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      appVersion: '${package.version}+${package.buildNumber}',
      locale: _locale(),
      deviceId: await _installationIds.getOrCreate(),
    );
    _registeredToken = token;
    AppLogger.info('push device registered');
  }

  Future<void> unregister({bool unregisterServer = true}) async {
    final token = _registeredToken ?? await _messaging.getToken();
    if (unregisterServer && token != null && token.isNotEmpty) {
      try {
        await _service.unregisterDevice(token);
      } on Object catch (error) {
        AppLogger.warn('push device unregister failed', error: error);
      }
    }
    await _messaging.deleteToken();
    _registeredToken = null;
  }
}

final pushRegistrationManagerProvider = Provider<PushRegistrationManager?>((
  ref,
) {
  if (!supportsNativePushNotifications || Firebase.apps.isEmpty) return null;
  return PushRegistrationManager(
    FirebaseMessaging.instance,
    ref.watch(notificationServiceProvider),
    ref.watch(installationIdStoreProvider),
    () => ref.read(localeControllerProvider).languageCode,
  );
});
