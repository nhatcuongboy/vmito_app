import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/app_bottom_navigation_bar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/court/presentation/live_session_screen.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _MockSocketClient extends Mock implements SocketClient {}

const _user = User(
  id: 'u1',
  email: 'player@example.com',
  role: UserRole.player,
  name: 'Player One',
);

void main() {
  late _MockSocketClient socket;

  setUp(() {
    socket = _MockSocketClient();
    when(() => socket.events).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('approved player sees all five mobile destinations', (
    tester,
  ) async {
    await _pump(
      tester,
      socket: socket,
      session: const Session(
        id: 's1',
        name: 'Tuesday badminton',
        status: SessionStatus.inProgress,
        players: [
          SessionPlayer(
            id: 'p1',
            userId: 'u1',
            name: 'Player One',
          ),
        ],
      ),
    );

    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Trạng thái'), findsOneWidget);
    expect(find.text('Sân'), findsOneWidget);
    expect(find.text('Kết quả'), findsOneWidget);
    expect(find.text('Thanh toán'), findsOneWidget);
    expect(find.byType(AppBottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player-live-tab-2')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unapproved account receives the access error CTA', (
    tester,
  ) async {
    await _pump(
      tester,
      socket: socket,
      session: const Session(
        id: 's1',
        name: 'Tuesday badminton',
        status: SessionStatus.inProgress,
        players: [
          SessionPlayer(
            id: 'p1',
            userId: 'u1',
            registrationStatus: RegistrationStatus.pending,
          ),
        ],
      ),
    );

    expect(find.textContaining('chưa được duyệt'), findsOneWidget);
    expect(find.text('Về chi tiết kèo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wide layout switches to a navigation rail', (tester) async {
    await _pump(
      tester,
      socket: socket,
      size: const Size(900, 900),
      session: const Session(
        id: 's1',
        name: 'Tuesday badminton',
        status: SessionStatus.inProgress,
        players: [
          SessionPlayer(id: 'p1', userId: 'u1', name: 'Player One'),
        ],
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('results tab is player-filtered and read only', (tester) async {
    await _pump(
      tester,
      socket: socket,
      playerMatches: const [
        Match(
          id: 'm1',
          sessionId: 's1',
          courtId: 'c1',
          status: MatchStatus.finished,
          players: [MatchPlayer(id: 'mp1', playerId: 'p1')],
        ),
      ],
      session: const Session(
        id: 's1',
        name: 'Tuesday badminton',
        status: SessionStatus.inProgress,
        players: [SessionPlayer(id: 'p1', userId: 'u1', name: 'Player One')],
      ),
    );

    await tester.tap(find.text('Kết quả'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-result-card-m1')), findsOneWidget);
    expect(find.byKey(const Key('host-result-edit-m1')), findsNothing);
    expect(find.byKey(const Key('host-result-delete-m1')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required SocketClient socket,
  required Session session,
  Size size = const Size(390, 844),
  List<Match> playerMatches = const [],
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socketClientProvider.overrideWithValue(socket),
        socketConnectionProvider.overrideWith((_) => Stream.value(true)),
        liveSessionRealtimeProvider.overrideWith((_, _) {}),
        currentUserProvider.overrideWithValue(_user),
        sessionDetailProvider.overrideWith((_, _) async => session),
        playerStatisticsProvider.overrideWith((_, _) async => const []),
        playerMatchHistoryProvider.overrideWith((_, _) async => playerMatches),
        ratingEligibilityProvider.overrideWith(
          (_, _) async => const RatingEligibility(
            canRateHost: false,
            canRatePlayers: [],
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LiveSessionScreen(sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
