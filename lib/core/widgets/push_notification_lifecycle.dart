import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/notifications/app_local_notifications.dart';
import 'package:vmito_app/core/notifications/push_registration_manager.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/notification/domain/notification_routing.dart';

/// Connects FCM to authentication, local foreground presentation and routing.
class PushNotificationLifecycle extends ConsumerStatefulWidget {
  const PushNotificationLifecycle({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<PushNotificationLifecycle> createState() =>
      _PushNotificationLifecycleState();
}

class _PushNotificationLifecycleState
    extends ConsumerState<PushNotificationLifecycle> {
  ProviderSubscription<AuthState>? _authSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<String>? _localActionSubscription;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AuthState>(
      authControllerProvider,
      (_, next) => _handleAuth(next),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (!mounted || _initialized) return;
    _initialized = true;

    if (!supportsNativePushNotifications) return;

    final local = ref.read(appLocalNotificationsProvider);
    await local.initialize();
    if (!mounted) return;
    _localActionSubscription = local.actions.listen(_openRoute);
    final initialLocalAction = local.takeInitialAction();
    if (initialLocalAction != null) _openRoute(initialLocalAction);

    if (Firebase.apps.isEmpty) return;
    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );
    _tokenSubscription = messaging.onTokenRefresh.listen((token) async {
      if (ref.read(authControllerProvider).status != AuthStatus.authenticated) {
        return;
      }
      try {
        await ref.read(pushRegistrationManagerProvider)?.registerToken(token);
      } on Object catch (error) {
        AppLogger.warn('push token refresh registration failed', error: error);
      }
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _openMessage(initialMessage);
    await _handleAuth(ref.read(authControllerProvider));
  }

  Future<void> _handleAuth(AuthState auth) async {
    if (!_initialized || auth.status != AuthStatus.authenticated) return;
    try {
      await ref.read(pushRegistrationManagerProvider)?.sync();
    } on Object catch (error) {
      // Push must never prevent sign-in or make the whole app unusable when
      // the device-registration endpoint is temporarily unavailable.
      AppLogger.warn('push registration failed', error: error);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString();
    final route = _routeFor(message.data);
    if (title != null && title.isNotEmpty && body != null && body.isNotEmpty) {
      final isCourtCall =
          message.data['action'] == 'court_call' ||
          message.data['courtNumber'] != null;
      await ref
          .read(appLocalNotificationsProvider)
          .show(
            title: title,
            body: body,
            payload: route,
            channel: isCourtCall
                ? AppNotificationChannel.courtCall
                : AppNotificationChannel.general,
          );
    }
    unawaited(
      ref.read(notificationControllerProvider.notifier).refreshUnreadCount(),
    );
  }

  void _openMessage(RemoteMessage message) =>
      _openRoute(_routeFor(message.data));

  String _routeFor(Map<String, dynamic> data) => getPushNotificationTargetRoute(
    data,
    userRole: ref.read(currentUserProvider)?.role,
  );

  void _openRoute(String route) {
    if (!mounted || !route.startsWith('/') || route.startsWith('//')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.router.go(route);
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    unawaited(_messageSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    unawaited(_localActionSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
