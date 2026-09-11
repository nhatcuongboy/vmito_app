import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/application/host_tournaments_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class _MockTournamentService extends Mock implements TournamentService {}

class _MockManagementService extends Mock
    implements TournamentManagementService {}

const _host = User(id: 'u1', email: 'host@vmito.com', role: UserRole.host);
const _admin = User(id: 'a1', email: 'admin@vmito.com', role: UserRole.admin);

TournamentSummary _tournament(
  String id, {
  required String name,
  TournamentStatus status = TournamentStatus.preparing,
  int startDay = 1,
  int createdDay = 1,
}) => TournamentSummary(
  id: id,
  name: name,
  startDate: DateTime.utc(2026, 6, startDay),
  endDate: DateTime.utc(2026, 6, startDay),
  createdAt: DateTime.utc(2026, 5, createdDay),
  status: status,
  isPublished: true,
);

final List<TournamentSummary> _fixtures = [
  _tournament('open-b', name: 'Beta', startDay: 20, createdDay: 3),
  _tournament(
    'live',
    name: 'alpha',
    status: TournamentStatus.inProgress,
    startDay: 10,
  ),
  _tournament(
    'done',
    name: 'Gamma',
    status: TournamentStatus.finished,
    startDay: 2,
    createdDay: 9,
  ),
  _tournament(
    'off',
    name: 'Delta',
    status: TournamentStatus.cancelled,
    startDay: 5,
    createdDay: 5,
  ),
];

ProviderContainer _container(
  TournamentService service, {
  TournamentManagementService? management,
  User user = _host,
}) {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      tournamentServiceProvider.overrideWithValue(service),
      if (management != null)
        tournamentManagementServiceProvider.overrideWithValue(management),
    ],
  );
  addTearDown(container.dispose);
  // Keep the auto-dispose provider alive for the whole test.
  container.listen(hostTournamentsControllerProvider, (_, _) {});
  return container;
}

List<String> _visibleIds(ProviderContainer container) => [
  for (final item in container.read(hostTournamentsControllerProvider).visible)
    item.id,
];

void main() {
  late _MockTournamentService service;

  setUp(() {
    service = _MockTournamentService();
    when(service.mine).thenAnswer((_) async => _fixtures);
    when(service.manageable).thenAnswer((_) async => _fixtures);
  });

  test('a host loads their own tournaments', () async {
    final container = _container(service);

    await container
        .read(hostTournamentsControllerProvider.notifier)
        .loadInitial();

    verify(service.mine).called(1);
    verifyNever(service.manageable);
    expect(container.read(hostTournamentsControllerProvider).hasLoaded, isTrue);
  });

  test('an admin loads the system-wide list', () async {
    final container = _container(service, user: _admin);

    await container
        .read(hostTournamentsControllerProvider.notifier)
        .loadInitial();

    verify(service.manageable).called(1);
    verifyNever(service.mine);
  });

  test('tabs bucket the raw status the way the web header does', () async {
    final container = _container(service);
    final controller = container.read(
      hostTournamentsControllerProvider.notifier,
    );
    await controller.loadInitial();

    // Open is the default tab, sorted by start date.
    expect(_visibleIds(container), ['live', 'open-b']);

    controller.setTab(HostTournamentTab.ended);
    expect(_visibleIds(container), ['done', 'off']);

    controller.setTab(HostTournamentTab.all);
    expect(_visibleIds(container), ['done', 'off', 'live', 'open-b']);
  });

  test('search matches names case-insensitively', () async {
    final container = _container(service);
    final controller = container.read(
      hostTournamentsControllerProvider.notifier,
    );
    await controller.loadInitial();
    controller
      ..setTab(HostTournamentTab.all)
      ..setSearch('  ALPHA ');

    expect(_visibleIds(container), ['live']);
    expect(container.read(hostTournamentsControllerProvider).query, 'ALPHA');
  });

  test('every sort option orders the list', () async {
    final container = _container(service);
    final controller = container.read(
      hostTournamentsControllerProvider.notifier,
    );
    await controller.loadInitial();
    controller
      ..setTab(HostTournamentTab.all)
      ..setSort(TournamentBrowseSort.newest);
    expect(_visibleIds(container), ['done', 'off', 'open-b', 'live']);

    controller.setSort(TournamentBrowseSort.nameAsc);
    expect(_visibleIds(container), ['live', 'open-b', 'off', 'done']);

    controller.setSort(TournamentBrowseSort.nameDesc);
    expect(_visibleIds(container), ['done', 'off', 'open-b', 'live']);
  });

  test('delete removes the row locally without refetching', () async {
    final management = _MockManagementService();
    when(
      () => management.deleteTournament('open-b'),
    ).thenAnswer((_) async {});
    final container = _container(service, management: management);
    final controller = container.read(
      hostTournamentsControllerProvider.notifier,
    );
    await controller.loadInitial();

    await controller.delete('open-b');

    verify(() => management.deleteTournament('open-b')).called(1);
    verify(service.mine).called(1);
    final state = container.read(hostTournamentsControllerProvider);
    expect(state.tournaments.map((item) => item.id), isNot(contains('open-b')));
    expect(state.deletingId, isNull);
  });

  test('a failed delete keeps the row and rethrows', () async {
    final management = _MockManagementService();
    when(() => management.deleteTournament('open-b')).thenThrow(
      const ApiException(kind: ApiErrorKind.forbidden, message: 'no'),
    );
    final container = _container(service, management: management);
    final controller = container.read(
      hostTournamentsControllerProvider.notifier,
    );
    await controller.loadInitial();

    await expectLater(
      controller.delete('open-b'),
      throwsA(isA<ApiException>()),
    );

    final state = container.read(hostTournamentsControllerProvider);
    expect(state.tournaments.map((item) => item.id), contains('open-b'));
    expect(state.deletingId, isNull);
  });

  test('a failed refresh keeps loaded content and exposes the error', () async {
    final container = _container(service);
    final controller = container.read(
      hostTournamentsControllerProvider.notifier,
    );
    await controller.loadInitial();
    when(service.mine).thenThrow(
      const ApiException(kind: ApiErrorKind.network, message: 'offline'),
    );

    await controller.refresh();

    final state = container.read(hostTournamentsControllerProvider);
    expect(state.tournaments, hasLength(4));
    expect(state.error, isA<ApiException>());
    expect(state.isLoading, isFalse);
  });
}
