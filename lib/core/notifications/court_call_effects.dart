import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vmito_app/core/notifications/app_local_notifications.dart';

abstract interface class CourtCallEffects {
  Future<void> initialize();

  Future<void> notify({
    required String title,
    required String message,
    required String payload,
  });

  /// Calls a player to their court. Repeats — see the implementation.
  Future<void> speak(String message, String languageCode);

  /// Reads [phrases] aloud once, in order.
  ///
  /// Distinct from [speak], which repeats three times because it is chasing a
  /// player who is not looking at their phone. This one is the host tapping a
  /// speaker button with the gym in earshot; repeating it would be noise.
  Future<void> announce(List<String> phrases, String languageCode);
}

class PlatformCourtCallEffects implements CourtCallEffects {
  PlatformCourtCallEffects({
    required this._notifications,
    FlutterTts? tts,
  }) : _tts = tts ?? FlutterTts();

  final AppLocalNotifications _notifications;
  final FlutterTts _tts;

  @override
  Future<void> initialize() => _notifications.initialize();

  @override
  Future<void> notify({
    required String title,
    required String message,
    required String payload,
  }) async {
    await _notifications.show(
      title: title,
      body: message,
      payload: payload,
      channel: AppNotificationChannel.courtCall,
    );
  }

  @override
  Future<void> speak(String message, String languageCode) async {
    await _prepare(languageCode);
    for (var repeat = 0; repeat < 3; repeat++) {
      await _tts.speak(message);
      if (repeat < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
    }
  }

  @override
  Future<void> announce(List<String> phrases, String languageCode) async {
    await _prepare(languageCode);
    // Cancel first: a host tapping two courts in a row should hear the second,
    // not the second queued behind the first.
    await _tts.stop();
    for (final phrase in phrases) {
      if (phrase.trim().isEmpty) continue;
      await _tts.speak(phrase);
    }
  }

  /// The engine's voice follows the app's locale, not a hardcoded Vietnamese —
  /// see docs/I18N.md on the web app's hardcoding.
  Future<void> _prepare(String languageCode) async {
    final language = switch (languageCode) {
      'en' => 'en-US',
      'zh' => 'zh-CN',
      _ => 'vi-VN',
    };
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(.48);
    await _tts.awaitSpeakCompletion(true);
  }
}

final courtCallEffectsProvider = Provider<CourtCallEffects>(
  (ref) => PlatformCourtCallEffects(
    notifications: ref.watch(appLocalNotificationsProvider),
  ),
);
