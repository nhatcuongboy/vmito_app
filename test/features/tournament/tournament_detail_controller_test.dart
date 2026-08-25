import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class _TournamentService extends Mock implements TournamentService {}

void main() {
  test('loads independent home sections and preserves their data', () async {
    final service = _TournamentService();
    final tournament = _tournament();
    when(
      () => service.detail('vmito-open'),
    ).thenAnswer((_) async => tournament);
    when(() => service.matches('t1')).thenAnswer((_) async => const []);
    when(() => service.sponsors('t1')).thenAnswer(
      (_) async => const [TournamentSponsor(id: 's1', name: 'Vmito')],
    );
    when(() => service.standings('c1')).thenAnswer((_) async => const []);
    final container = ProviderContainer(
      overrides: [tournamentServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final state = await container.read(
      tournamentDetailControllerProvider('vmito-open').future,
    );

    expect(state.tournament.id, 't1');
    expect(state.sponsors.single.name, 'Vmito');
    expect(state.matchesError, isNull);
    verify(() => service.standings('c1')).called(1);
  });

  test('a sponsor failure does not fail the detail screen', () async {
    final service = _TournamentService();
    when(
      () => service.detail('vmito-open'),
    ).thenAnswer((_) async => _tournament());
    when(() => service.matches('t1')).thenAnswer((_) async => const []);
    when(() => service.sponsors('t1')).thenThrow(Exception('sponsors down'));
    when(() => service.standings('c1')).thenAnswer((_) async => const []);
    final container = ProviderContainer(
      overrides: [tournamentServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final state = await container.read(
      tournamentDetailControllerProvider('vmito-open').future,
    );

    expect(state.tournament.name, 'Vmito Open');
    expect(state.sponsors, isEmpty);
    expect(state.sponsorsError, isA<Exception>());
  });
}

TournamentDetail _tournament() => TournamentDetail(
  id: 't1',
  slug: 'vmito-open',
  name: 'Vmito Open',
  startDate: DateTime(2026, 8, 25),
  endDate: DateTime(2026, 8, 26),
  hostId: 'host-1',
  status: TournamentStatus.finished,
  isPublished: true,
  categories: const [
    TournamentCategory(
      id: 'c1',
      name: 'Đôi nam',
      type: 'MEN_DOUBLES',
      registrationMode: TournamentRegistrationMode.team,
      format: TournamentCategoryFormat.roundRobin,
      registrationCount: 4,
    ),
  ],
  venues: const [],
  playerCount: 8,
  pairCount: 4,
);
