import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/application/tournament_standings_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_standings_preferences.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_standings.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class _TournamentService extends Mock implements TournamentService {}

class _SocketClient extends Mock implements SocketClient {}

class _AuthController extends AuthController {
  _AuthController(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}

class _Preferences implements TournamentStandingsPreferences {
  bool value = true;

  @override
  Future<bool> readShowPlayerNames() async => value;

  @override
  Future<void> writeShowPlayerNames({required bool value}) async {
    this.value = value;
  }
}

void main() {
  test('loads the full snapshot and persists filters locally', () async {
    final service = _TournamentService();
    final preferences = _Preferences();
    _stubSnapshot(service);
    final container = _container(service, preferences: preferences);
    addTearDown(container.dispose);
    final controller = container.read(
      tournamentStandingsControllerProvider('open').notifier,
    );

    await controller.load();
    controller
      ..selectCategory('c1')
      ..setStage(TournamentStandingsStage.playoffs)
      ..setView(TournamentStandingsView.overall);
    await controller.setShowPlayerNames(value: false);
    final state = container.read(
      tournamentStandingsControllerProvider('open'),
    );

    expect(state.tournament?.id, 't1');
    expect(state.matches, hasLength(1));
    expect(state.standingsByCategory['c1'], hasLength(1));
    expect(state.selectedCategoryId, 'c1');
    expect(state.stage, TournamentStandingsStage.playoffs);
    expect(state.view, TournamentStandingsView.overall);
    expect(state.showPlayerNames, isFalse);
    expect(preferences.value, isFalse);
  });

  test('host recalculates one group and duplicate calls are ignored', () async {
    final service = _TournamentService();
    _stubSnapshot(service);
    final pending = Completer<void>();
    when(
      () => service.calculateStandings('c1', 'g1'),
    ).thenAnswer((_) => pending.future);
    const host = User(
      id: 'host-1',
      email: 'host@example.com',
      role: UserRole.host,
    );
    final container = _container(
      service,
      auth: const AuthState(status: AuthStatus.authenticated, user: host),
    );
    addTearDown(container.dispose);
    final controller = container.read(
      tournamentStandingsControllerProvider('open').notifier,
    );
    await controller.load();

    final first = controller.recalculate('c1', 'g1');
    await Future<void>.delayed(Duration.zero);
    await controller.recalculate('c1', 'g1');
    verify(() => service.calculateStandings('c1', 'g1')).called(1);
    expect(
      container
          .read(tournamentStandingsControllerProvider('open'))
          .recalculatingGroupId,
      'g1',
    );
    pending.complete();
    await first;
    expect(
      container
          .read(tournamentStandingsControllerProvider('open'))
          .recalculatingGroupId,
      isNull,
    );
    verify(() => service.standings('c1')).called(2);
  });

  test('spectator cannot call the standings mutation', () async {
    final service = _TournamentService();
    _stubSnapshot(service);
    final container = _container(service);
    addTearDown(container.dispose);
    final controller = container.read(
      tournamentStandingsControllerProvider('open').notifier,
    );
    await controller.load();

    await controller.recalculate('c1', 'g1');

    verifyNever(() => service.calculateStandings(any(), any()));
  });

  test('score events debounce a silent standings refresh', () async {
    final service = _TournamentService();
    _stubSnapshot(service, status: TournamentStatus.inProgress);
    final events = StreamController<SocketEvent>.broadcast();
    final connections = StreamController<bool>.broadcast();
    addTearDown(events.close);
    addTearDown(connections.close);
    final socket = _SocketClient();
    when(() => socket.events).thenAnswer((_) => events.stream);
    when(() => socket.connectionState).thenAnswer((_) => connections.stream);
    when(socket.connect).thenReturn(null);
    when(() => socket.joinTournament(any())).thenReturn(null);
    when(() => socket.leaveTournament(any())).thenReturn(null);
    final container = _container(service, socket: socket);
    addTearDown(container.dispose);
    final controller = container.read(
      tournamentStandingsControllerProvider('open').notifier,
    );
    await controller.load();

    events
      ..add(
        const SocketEvent(TournamentEvent.scoreUpdated, {
          'tournamentId': 't1',
        }),
      )
      ..add(
        const SocketEvent(TournamentEvent.matchEnded, {'tournamentId': 't1'}),
      );
    await Future<void>.delayed(const Duration(milliseconds: 550));

    verify(() => service.matches('t1')).called(2);
    verify(() => service.standings('c1')).called(2);
  });
}

ProviderContainer _container(
  TournamentService service, {
  _Preferences? preferences,
  SocketClient? socket,
  AuthState auth = const AuthState(status: AuthStatus.unauthenticated),
}) => ProviderContainer(
  overrides: [
    tournamentServiceProvider.overrideWithValue(service),
    tournamentStandingsPreferencesProvider.overrideWithValue(
      preferences ?? _Preferences(),
    ),
    authControllerProvider.overrideWith(() => _AuthController(auth)),
    if (socket != null)
      tournamentSocketClientProvider.overrideWith((ref, id) => socket),
  ],
);

void _stubSnapshot(
  _TournamentService service, {
  TournamentStatus status = TournamentStatus.finished,
}) {
  when(() => service.detail('open')).thenAnswer(
    (_) async => TournamentDetail(
      id: 't1',
      slug: 'open',
      name: 'Open',
      startDate: DateTime(2026, 8),
      endDate: DateTime(2026, 8, 2),
      hostId: 'host-1',
      status: status,
      isPublished: true,
      categories: const [
        TournamentCategory(
          id: 'c1',
          name: 'Doubles',
          type: 'MEN_DOUBLES',
          registrationMode: TournamentRegistrationMode.team,
          format: TournamentCategoryFormat.roundRobin,
          registrationCount: 2,
        ),
      ],
      venues: const [],
      playerCount: 4,
      pairCount: 2,
    ),
  );
  when(() => service.matches('t1')).thenAnswer(
    (_) async => const [
      TournamentMatch(
        id: 'm1',
        categoryId: 'c1',
        round: 'GROUP',
        matchNumber: 1,
        status: TournamentMatchStatus.finished,
        participants: [],
        groupId: 'g1',
      ),
    ],
  );
  when(() => service.standings('c1')).thenAnswer(
    (_) async => [
      TournamentStandingGroup(
        group: const TournamentCategoryGroup(
          id: 'g1',
          categoryId: 'c1',
          number: 1,
          name: 'A',
        ),
        rows: [_standing()],
      ),
    ],
  );
}

TournamentStanding _standing() => const TournamentStanding(
  registration: TournamentRegistration(id: 'r1', pairName: 'Team One'),
  categoryRegistrationId: 'r1',
  matchesPlayed: 1,
  matchesWon: 1,
  matchesLost: 0,
  matchesDrawn: 0,
  matchesForfeited: 0,
  matchesCancelled: 0,
  points: 2,
  pointsFor: 21,
  pointsAgainst: 10,
  pointDifference: 11,
  gamesWon: 2,
  gameDifference: 2,
  recentForm: [TournamentStandingResult.win],
  rank: 1,
);
