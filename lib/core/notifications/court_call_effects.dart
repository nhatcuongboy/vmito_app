import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class CourtCallEffects {
  Stream<String> get actions;

  Future<void> initialize();

  Future<void> notify({
    required String title,
    required String message,
    required String payload,
  });

  Future<void> speak(String message, String languageCode);
}

class PlatformCourtCallEffects implements CourtCallEffects {
  PlatformCourtCallEffects({
    FlutterLocalNotificationsPlugin? notifications,
    FlutterTts? tts,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _tts = tts ?? FlutterTts();

  final FlutterLocalNotificationsPlugin _notifications;
  final FlutterTts _tts;
  final StreamController<String> _actions = StreamController.broadcast();
  Future<void>? _initialization;

  @override
  Stream<String> get actions => _actions.stream;

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _notifications.initialize(
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
    final launch = await _notifications.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        payload != null &&
        payload.isNotEmpty) {
      _actions.add(payload);
    }
  }

  Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  Future<void> notify({
    required String title,
    required String message,
    required String payload,
  }) async {
    await initialize();
    await _requestPermissions();
    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: message,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'court_calls',
          'Court calls',
          channelDescription: 'Calls players to their assigned court',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> speak(String message, String languageCode) async {
    final language = switch (languageCode) {
      'en' => 'en-US',
      'zh' => 'zh-CN',
      _ => 'vi-VN',
    };
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(.48);
    await _tts.awaitSpeakCompletion(true);
    for (var repeat = 0; repeat < 3; repeat++) {
      await _tts.speak(message);
      if (repeat < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
    }
  }
}

final courtCallEffectsProvider = Provider<CourtCallEffects>(
  (ref) => PlatformCourtCallEffects(),
);
