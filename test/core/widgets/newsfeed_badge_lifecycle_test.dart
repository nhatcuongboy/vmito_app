import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/widgets/newsfeed_badge_lifecycle.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this.initialState);

  final AuthState initialState;

  @override
  AuthState build() => initialState;
}

class _RecordingBadgeController extends NewsfeedBadgeController {
  int resets = 0;
  int fetches = 0;
  int marks = 0;
  int realtimeHints = 0;

  @override
  NewsfeedBadgeState build() => const NewsfeedBadgeState();

  @override
  void reset() => resets++;

  @override
  Future<void> fetchCount() async {
    fetches++;
  }

  @override
  Future<void> markAsRead() async {
    marks++;
  }

  @override
  void handleRealtimeHint() => realtimeHints++;
}

class _MockSocketClient extends Mock implements SocketClient {}

GoRouter _router() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (_, _) => const Scaffold(body: Text('home')),
    ),
    GoRoute(
      path: AppRoutes.feed,
      builder: (_, _) => const Scaffold(body: Text('feed')),
      routes: [
        GoRoute(
          path: 'manage',
          builder: (_, _) => const Scaffold(body: Text('manage')),
        ),
        GoRoute(
          path: ':postId',
          builder: (_, _) => const Scaffold(body: Text('post')),
        ),
      ],
    ),
  ],
);

Widget _harness({
  required GoRouter router,
  required AuthState auth,
  required _RecordingBadgeController badge,
  required SocketClient socket,
}) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(() => _TestAuthController(auth)),
    newsfeedBadgeControllerProvider.overrideWith(() => badge),
    socketClientProvider.overrideWithValue(socket),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    builder: (context, child) => NewsfeedBadgeLifecycle(
      router: router,
      child: child ?? const SizedBox.shrink(),
    ),
  ),
);

void main() {
  const user = User(
    id: 'user-1',
    email: 'user@example.test',
    role: UserRole.player,
  );

  testWidgets('coordinates route, resume and authoritative socket hints', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    final socket = _MockSocketClient();
    when(socket.connect).thenReturn(null);
    when(
      () => socket.on(SessionEvent.newPostCreated),
    ).thenAnswer((_) => events.stream);
    final badge = _RecordingBadgeController();
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _harness(
        router: router,
        auth: const AuthState(status: AuthStatus.authenticated, user: user),
        badge: badge,
        socket: socket,
      ),
    );
    await tester.pumpAndSettle();

    expect(badge.resets, 1);
    expect(badge.fetches, 1);
    expect(events.hasListener, isTrue);

    events.add({'authorId': user.id, 'postId': 'own'});
    await tester.pump();
    expect(badge.realtimeHints, 0);

    events.add({'authorId': 'other-user', 'postId': 'new'});
    await tester.pump();
    expect(badge.realtimeHints, 1);

    router.go(AppRoutes.feed);
    await tester.pumpAndSettle();
    expect(badge.marks, 1);

    router.go(AppRoutes.socialPost('post-1'));
    await tester.pumpAndSettle();
    expect(badge.marks, 1);

    router.go(AppRoutes.manageClubs);
    await tester.pumpAndSettle();
    expect(badge.fetches, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(badge.fetches, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(events.hasListener, isFalse);
  });

  testWidgets('guest state resets without connecting or fetching', (
    tester,
  ) async {
    final socket = _MockSocketClient();
    final badge = _RecordingBadgeController();
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _harness(
        router: router,
        auth: const AuthState(
          status: AuthStatus.guest,
          user: User(
            id: 'guest-1',
            email: '',
            role: UserRole.guest,
          ),
        ),
        badge: badge,
        socket: socket,
      ),
    );
    await tester.pumpAndSettle();

    expect(badge.resets, 0);
    expect(badge.fetches, 0);
    expect(badge.marks, 0);
    verifyNever(socket.connect);
  });
}
