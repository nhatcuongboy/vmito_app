import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/application/tournament_schedule_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_schedule_preferences.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class _TournamentService extends Mock implements TournamentService {}

class _SocketClient extends Mock implements SocketClient {}

class _AuthController extends AuthController {
  _AuthController(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}

class _Preferences implements TournamentSchedulePreferences {
  bool value = false;

  @override
  Future<bool> readShowPlayerNames() async => value;

  @override
  Future<void> writeShowPlayerNames({required bool value}) async {
    this.value = value;
  }
}

class _ScheduleDraft extends Fake implements TournamentScheduleUpdateDraft {}

class _ResultDraft extends Fake implements TournamentResultDraft {}

void main() {
  setUpAll(() {
    registerFallbackValue(_ScheduleDraft());
    registerFallbackValue(_ResultDraft());
  });

  test(
    'supporting failures are isolated and spectator skips admin APIs',
    () async {
      final service = _TournamentService();
      _stubBase(service);
      when(() => service.courts('t1')).thenThrow(Exception('courts down'));
      final container = _container(service);
      addTearDown(container.dispose);

      await container
          .read(tournamentScheduleControllerProvider('open').notifier)
          .load();
      final state = container.read(
        tournamentScheduleControllerProvider('open'),
      );

      expect(state.error, isNull);
      expect(state.matches, hasLength(1));
      expect(state.courts, isEmpty);
      expect(state.courtsError, isA<Exception>());
      verifyNever(() => service.umpires(any()));
      verifyNever(() => service.ownAssignments(any()));

      final controller = container.read(
        tournamentScheduleControllerProvider('open').notifier,
      );
      await controller.updateSchedule(
        const TournamentScheduleUpdateDraft(
          matchId: 'm1',
          matchCode: 'A-1',
        ),
      );
      await controller.saveResult(
        'm1',
        const TournamentResultDraft(score: '21-10'),
      );
      await controller.resetResult('m1');
      await controller.deleteMatch('m1');
      await controller.completeGroupStage('c1');
      verifyNever(() => service.updateMatchSchedule(any()));
      verifyNever(() => service.saveResult(any(), any()));
      verifyNever(() => service.resetResult(any()));
      verifyNever(() => service.deleteMatch(any()));
      verifyNever(() => service.completeGroupStage(any()));
    },
  );

  test(
    'referee loads only own assignments and can enable assignment filter',
    () async {
      final service = _TournamentService();
      _stubBase(service);
      when(() => service.courts('t1')).thenAnswer((_) async => const []);
      when(
        () => service.ownAssignments('t1'),
      ).thenAnswer((_) async => [_match()]);
      const referee = User(
        id: 'ref-1',
        email: 'ref@example.com',
        role: UserRole.referee,
      );
      final container = _container(
        service,
        auth: const AuthState(status: AuthStatus.authenticated, user: referee),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        tournamentScheduleControllerProvider('open').notifier,
      );

      await controller.load();
      controller.setRefereeOnly(value: true);
      final state = container.read(
        tournamentScheduleControllerProvider('open'),
      );

      expect(state.ownAssignmentIds, {'m1'});
      expect(state.filteredMatches, hasLength(1));
      verifyNever(() => service.umpires(any()));
    },
  );

  test(
    'schedule mutation is optimistic, rolls back, and blocks duplicates',
    () async {
      final service = _TournamentService();
      _stubBase(service);
      when(() => service.courts('t1')).thenAnswer(
        (_) async => const [TournamentCourt(id: 'court-1', number: 1)],
      );
      when(() => service.umpires('t1')).thenAnswer((_) async => const []);
      when(
        () => service.ownAssignments('t1'),
      ).thenAnswer((_) async => const []);
      when(() => service.updateMatchCode('m1', 'A-1')).thenAnswer((_) async {});
      final pending = Completer<void>();
      when(
        () => service.updateMatchSchedule(any()),
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
        tournamentScheduleControllerProvider('open').notifier,
      );
      await controller.load();
      final draft = TournamentScheduleUpdateDraft(
        matchId: 'm1',
        matchCode: 'A-1',
        courtId: 'court-1',
        startTime: DateTime(2026, 8, 27, 9),
        endTime: DateTime(2026, 8, 27, 10),
      );

      final first = controller.updateSchedule(draft);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(tournamentScheduleControllerProvider('open'))
            .matches
            .single
            .courtId,
        'court-1',
      );
      await controller.updateSchedule(draft);
      verify(() => service.updateMatchSchedule(any())).called(1);
      pending.completeError(Exception('schedule failed'));
      await expectLater(first, throwsException);
      expect(
        container
            .read(tournamentScheduleControllerProvider('open'))
            .matches
            .single
            .courtId,
        isNull,
      );
    },
  );

  test('result mutation refreshes matches and clears busy state', () async {
    final service = _TournamentService();
    _stubBase(service);
    when(() => service.courts('t1')).thenAnswer((_) async => const []);
    when(() => service.umpires('t1')).thenAnswer((_) async => const []);
    when(() => service.ownAssignments('t1')).thenAnswer((_) async => const []);
    when(() => service.saveResult('m1', any())).thenAnswer(
      (_) async => _match(status: TournamentMatchStatus.finished),
    );
    var reads = 0;
    when(() => service.matches('t1')).thenAnswer((_) async {
      reads++;
      return [
        _match(
          status: reads > 1
              ? TournamentMatchStatus.finished
              : TournamentMatchStatus.scheduled,
        ),
      ];
    });
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
      tournamentScheduleControllerProvider('open').notifier,
    );
    await controller.load();

    await controller.saveResult(
      'm1',
      const TournamentResultDraft(score: '21-10', winnerId: 'r1'),
    );
    final state = container.read(tournamentScheduleControllerProvider('open'));
    expect(state.matches.single.status, TournamentMatchStatus.finished);
    expect(state.busyMatchIds, isEmpty);
    verify(() => service.matches('t1')).called(2);
  });

  test('realtime merges score and reconnect refetches the snapshot', () async {
    final service = _TournamentService();
    _stubBase(
      service,
      status: TournamentStatus.inProgress,
    );
    when(() => service.courts('t1')).thenAnswer((_) async => const []);
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
      tournamentScheduleControllerProvider('open').notifier,
    );
    await controller.load();

    events.add(
      const SocketEvent(TournamentEvent.scoreUpdated, {
        'tournamentId': 't1',
        'match': {
          'matchId': 'm1',
          'status': 'IN_PROGRESS',
          'currentSet': {'setNumber': 1, 'side1': 9, 'side2': 7},
        },
      }),
    );
    await Future<void>.delayed(Duration.zero);
    var state = container.read(tournamentScheduleControllerProvider('open'));
    expect(state.matches.single.sets.single.player1Score, 9);

    connections
      ..add(true)
      ..add(false)
      ..add(true);
    await Future<void>.delayed(Duration.zero);
    state = container.read(tournamentScheduleControllerProvider('open'));
    expect(state.matches.single.status, TournamentMatchStatus.scheduled);
    verify(() => service.matches('t1')).called(2);
  });

  test('unknown realtime match triggers one debounced refetch', () async {
    final service = _TournamentService();
    _stubBase(service, status: TournamentStatus.inProgress);
    when(() => service.courts('t1')).thenAnswer((_) async => const []);
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
    await container
        .read(tournamentScheduleControllerProvider('open').notifier)
        .load();

    for (var index = 0; index < 3; index++) {
      events.add(
        const SocketEvent(TournamentEvent.scoreUpdated, {
          'tournamentId': 't1',
          'match': {'matchId': 'new-match', 'status': 'SCHEDULED'},
        }),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 550));
    verify(() => service.matches('t1')).called(2);
  });
}

ProviderContainer _container(
  TournamentService service, {
  AuthState auth = const AuthState(status: AuthStatus.unauthenticated),
  SocketClient? socket,
}) => ProviderContainer(
  overrides: [
    tournamentServiceProvider.overrideWithValue(service),
    tournamentSchedulePreferencesProvider.overrideWithValue(_Preferences()),
    authControllerProvider.overrideWith(() => _AuthController(auth)),
    if (socket != null)
      tournamentSocketClientProvider.overrideWith((ref, id) => socket),
  ],
);

void _stubBase(
  TournamentService service, {
  String hostId = 'host-1',
  TournamentStatus status = TournamentStatus.finished,
}) {
  when(() => service.detail('open')).thenAnswer(
    (_) async => TournamentDetail(
      id: 't1',
      slug: 'open',
      name: 'Open',
      startDate: DateTime(2026, 8, 27),
      endDate: DateTime(2026, 8, 28),
      hostId: hostId,
      status: status,
      isPublished: true,
      categories: const [
        TournamentCategory(
          id: 'c1',
          name: 'Open',
          type: 'OPEN',
          registrationMode: TournamentRegistrationMode.team,
          format: TournamentCategoryFormat.roundRobin,
          registrationCount: 2,
        ),
      ],
      venues: const [],
      playerCount: 2,
      pairCount: 2,
    ),
  );
  when(() => service.matches('t1')).thenAnswer((_) async => [_match()]);
  when(() => service.categoryGroups('c1')).thenAnswer((_) async => const []);
}

TournamentMatch _match({
  TournamentMatchStatus status = TournamentMatchStatus.scheduled,
}) => TournamentMatch(
  id: 'm1',
  categoryId: 'c1',
  round: 'GROUP',
  matchNumber: 1,
  status: status,
  participants: const [
    TournamentMatchParticipant(
      position: 1,
      registrationId: 'r1',
      registration: TournamentRegistration(id: 'r1', pairName: 'Team 1'),
    ),
    TournamentMatchParticipant(
      position: 2,
      registrationId: 'r2',
      registration: TournamentRegistration(id: 'r2', pairName: 'Team 2'),
    ),
  ],
);
