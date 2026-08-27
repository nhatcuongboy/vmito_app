import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';

/// Coordinates the newsfeed badge with identity, navigation and app resume.
class NewsfeedBadgeLifecycle extends ConsumerStatefulWidget {
  const NewsfeedBadgeLifecycle({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<NewsfeedBadgeLifecycle> createState() =>
      _NewsfeedBadgeLifecycleState();
}

class _NewsfeedBadgeLifecycleState extends ConsumerState<NewsfeedBadgeLifecycle>
    with WidgetsBindingObserver {
  ProviderSubscription<AuthState>? _authSubscription;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  String? _authenticatedUserId;
  bool? _wasOnFeed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.router.routeInformationProvider.addListener(_handleRouteChange);
    _authSubscription = ref.listenManual<AuthState>(
      authControllerProvider,
      (_, next) => _handleAuthChange(next),
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant NewsfeedBadgeLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.router, widget.router)) return;

    oldWidget.router.routeInformationProvider.removeListener(
      _handleRouteChange,
    );
    widget.router.routeInformationProvider.addListener(_handleRouteChange);
    _wasOnFeed = null;
    _scheduleSync(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync(force: true);
  }

  void _handleAuthChange(AuthState auth) {
    final userId = auth.status == AuthStatus.authenticated
        ? auth.user?.id
        : null;
    if (_authenticatedUserId == userId) return;

    _authenticatedUserId = userId;
    _wasOnFeed = null;
    ref.read(newsfeedBadgeControllerProvider.notifier).reset();
    _replaceSocketSubscription(userId);
    if (userId != null) _scheduleSync(force: true);
  }

  void _replaceSocketSubscription(String? userId) {
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    if (userId == null) return;

    final socket = ref.read(socketClientProvider)..connect();
    _socketSubscription = socket.on(SessionEvent.newPostCreated).listen(
      (payload) {
        if (_authenticatedUserId != userId) return;
        if (payload['authorId']?.toString() == userId) return;
        ref.read(newsfeedBadgeControllerProvider.notifier).handleRealtimeHint();
      },
    );
  }

  void _handleRouteChange() => _sync();

  void _scheduleSync({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(force: force);
    });
  }

  void _sync({bool force = false}) {
    if (_authenticatedUserId == null) return;

    final location = widget.router.routeInformationProvider.value.uri.path;
    final isOnFeed = AppRoutes.isFeedLocation(location);
    if (!force && _wasOnFeed == isOnFeed) return;
    _wasOnFeed = isOnFeed;

    final controller = ref.read(newsfeedBadgeControllerProvider.notifier);
    if (isOnFeed) {
      unawaited(controller.markAsRead());
    } else {
      unawaited(controller.fetchCount());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.router.routeInformationProvider.removeListener(_handleRouteChange);
    _authSubscription?.close();
    unawaited(_socketSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
