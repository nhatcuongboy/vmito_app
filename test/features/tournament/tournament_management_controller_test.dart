import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class _TournamentService extends Mock implements TournamentService {}

class _ManagementService extends Mock implements TournamentManagementService {}

class _AuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'manager-1',
      email: 'manager@example.com',
      role: UserRole.player,
    ),
  );
}

void main() {
  test('keeps tournament data and exposes an access-loading failure', () async {
    final services = _services();
    when(
      () => services.management.access('t1'),
    ).thenThrow(Exception('access down'));
    final container = _container(services);
    addTearDown(container.dispose);
    final controller = container.read(
      tournamentManagementControllerProvider('open').notifier,
    );

    await controller.load();
    final state = container.read(
      tournamentManagementControllerProvider('open'),
    );

    expect(state.tournament?.id, 't1');
    expect(state.access, isNull);
    expect(state.error, isA<Exception>());
  });

  test('force reload retries access without reloading the whole app', () async {
    final services = _services();
    var attempts = 0;
    when(() => services.management.access('t1')).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('temporary');
      return const TournamentMyAccess(
        tournamentId: 't1',
        isHost: false,
        isAdmin: false,
        permissions: {TournamentPermission.results},
      );
    });
    final container = _container(services);
    addTearDown(container.dispose);
    final controller = container.read(
      tournamentManagementControllerProvider('open').notifier,
    );

    await controller.load();
    await controller.load(force: true);

    expect(
      container
          .read(tournamentManagementControllerProvider('open'))
          .access
          ?.permissions,
      {TournamentPermission.results},
    );
    verify(() => services.management.access('t1')).called(2);
  });

  test(
    'prevents duplicate tournament mutations while one is pending',
    () async {
      final services = _services();
      when(() => services.management.access('t1')).thenAnswer(
        (_) async => const TournamentMyAccess(
          tournamentId: 't1',
          isHost: true,
          isAdmin: false,
          permissions: {},
        ),
      );
      final completer = Completer<TournamentDetail>();
      final draft = DuplicateTournamentDraft(
        name: 'Copy',
        startDate: DateTime.utc(2026, 10),
        endDate: DateTime.utc(2026, 10, 2),
      );
      when(
        () => services.management.duplicateTournament('t1', draft),
      ).thenAnswer((_) => completer.future);
      final container = _container(services);
      addTearDown(container.dispose);
      final controller = container.read(
        tournamentManagementControllerProvider('open').notifier,
      );
      await controller.load();

      final first = controller.duplicate(draft);
      await expectLater(controller.duplicate(draft), throwsStateError);
      completer.complete(_tournament(id: 't2', slug: 'copy'));

      expect((await first).id, 't2');
      verify(
        () => services.management.duplicateTournament('t1', draft),
      ).called(1);
    },
  );
}

({TournamentService tournament, TournamentManagementService management})
_services() {
  final tournament = _TournamentService();
  final management = _ManagementService();
  when(
    () => tournament.detail('open'),
  ).thenAnswer((_) async => _tournament());
  return (tournament: tournament, management: management);
}

ProviderContainer _container(
  ({TournamentService tournament, TournamentManagementService management})
  services,
) => ProviderContainer(
  overrides: [
    tournamentServiceProvider.overrideWithValue(services.tournament),
    tournamentManagementServiceProvider.overrideWithValue(services.management),
    authControllerProvider.overrideWith(_AuthController.new),
  ],
);

TournamentDetail _tournament({String id = 't1', String slug = 'open'}) =>
    TournamentDetail(
      id: id,
      slug: slug,
      name: 'Vmito Open',
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 12),
      hostId: 'host-1',
      status: TournamentStatus.preparing,
      isPublished: false,
      categories: const [],
      venues: const [],
      playerCount: 0,
      pairCount: 0,
    );
