import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppNotificationChannel { general, courtCall }

/// The one owner of the local-notification plugin and its tap callback.
///
/// Keeping initialization here matters: the plugin uses one method channel,
/// so independently initializing it for FCM and court calls would make the
/// last callback silently replace the first one.
class AppLocalNotifications {
  AppLocalNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const generalChannelId = 'vmito_notifications';
  static const courtCallChannelId = 'court_calls';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _actions = StreamController.broadcast();
  Future<void>? _initialization;
  String? _initialAction;

  Stream<String> get actions => _actions.stream;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _actions.add(payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            generalChannelId,
            'Vmito notifications',
            description: 'Session, social, payment and system updates',
            importance: Importance.high,
          ),
        );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            courtCallChannelId,
            'Court calls',
            description: 'Calls players to their assigned court',
            importance: Importance.max,
          ),
        );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        payload != null &&
        payload.isNotEmpty) {
      _initialAction = payload;
    }
  }

  String? takeInitialAction() {
    final action = _initialAction;
    _initialAction = null;
    return action;
  }

  Future<void> show({
    required String title,
    required String body,
    required String payload,
    AppNotificationChannel channel = AppNotificationChannel.general,
  }) async {
    await initialize();
    final isCourtCall = channel == AppNotificationChannel.courtCall;
    await _plugin.show(
      id: DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isCourtCall ? courtCallChannelId : generalChannelId,
          isCourtCall ? 'Court calls' : 'Vmito notifications',
          channelDescription: isCourtCall
              ? 'Calls players to their assigned court'
              : 'Session, social, payment and system updates',
          importance: isCourtCall ? Importance.max : Importance.high,
          priority: isCourtCall ? Priority.max : Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: isCourtCall
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      payload: payload,
    );
  }

  void dispose() => unawaited(_actions.close());
}

final appLocalNotificationsProvider = Provider<AppLocalNotifications>((ref) {
  final notifications = AppLocalNotifications();
  ref.onDispose(notifications.dispose);
  return notifications;
});
