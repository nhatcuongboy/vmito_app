import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_player_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_sponsor_service.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';

class _Players extends Mock implements TournamentPlayerService {}

class _Sponsors extends Mock implements TournamentSponsorService {}

class _Access extends Mock implements TournamentManagementService {}

void main() {
  const player = TournamentPlayer(id: 'p', name: 'An');
  const draft = PlayerDraft(name: 'An');
  late _Players players;
  late _Sponsors sponsors;
  late _Access access;
  late ProviderContainer container;

  setUp(() {
    players = _Players();
    sponsors = _Sponsors();
    access = _Access();
    when(() => players.list('t')).thenAnswer((_) async => [player]);
    when(() => sponsors.list('t')).thenAnswer((_) async => []);
    when(() => access.access('t')).thenAnswer(
      (_) async => const TournamentMyAccess(
        tournamentId: 't',
        isHost: false,
        isAdmin: false,
        permissions: {TournamentPermission.participants},
      ),
    );
    container = ProviderContainer(
      overrides: [
        tournamentPlayerServiceProvider.overrideWithValue(players),
        tournamentSponsorServiceProvider.overrideWithValue(sponsors),
        tournamentManagementServiceProvider.overrideWithValue(access),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<TournamentPlayersController> loaded() async {
    final c = container.read(tournamentPlayersProvider('t').notifier);
    await c.reload();
    return c;
  }

  test(
    'independent resource load and failed refresh retain current data',
    () async {
      final c = await loaded();
      verifyNever(() => sponsors.list('t'));
      when(() => players.list('t')).thenThrow(StateError('offline'));
      await c.reload();
      expect(container.read(tournamentPlayersProvider('t')).items, [player]);
      expect(container.read(tournamentPlayersProvider('t')).error, isNotNull);
      when(() => players.list('t')).thenAnswer((_) async => []);
      await c.reload();
      expect(container.read(tournamentPlayersProvider('t')).items, isEmpty);
      expect(container.read(tournamentPlayersProvider('t')).error, isNull);
    },
  );

  test(
    'duplicate mutation rejected and server response merged without root reload',
    () async {
      final c = await loaded();
      final pending = Completer<TournamentPlayer>();
      when(
        () => players.save('t', draft, id: 'p'),
      ).thenAnswer((_) => pending.future);
      final first = c.save(draft, id: 'p');
      expect(await c.save(draft, id: 'p'), isFalse);
      await Future<void>.delayed(Duration.zero);
      pending.complete(const TournamentPlayer(id: 'p', name: 'Updated'));
      expect(await first, isTrue);
      expect(
        container.read(tournamentPlayersProvider('t')).items.single.name,
        'Updated',
      );
      verify(() => players.list('t')).called(1);
      verify(() => players.save('t', draft, id: 'p')).called(1);
    },
  );

  test('permission revocation and failed delete preserve collection', () async {
    final c = await loaded();
    when(() => access.access('t')).thenAnswer(
      (_) async => const TournamentMyAccess(
        tournamentId: 't',
        isHost: false,
        isAdmin: false,
        permissions: {TournamentPermission.structure},
      ),
    );
    expect(await c.delete('p'), isFalse);
    verifyNever(() => players.delete('p'));
    expect(container.read(tournamentPlayersProvider('t')).items, [player]);
  });

  test('successful delete affects only players', () async {
    final c = await loaded();
    when(() => players.delete('p')).thenAnswer((_) async {});
    expect(await c.delete('p'), isTrue);
    expect(container.read(tournamentPlayersProvider('t')).items, isEmpty);
    verifyNever(() => sponsors.list('t'));
  });

  test('sponsors require structure permission', () async {
    final c = container.read(tournamentSponsorsProvider('t').notifier);
    await c.reload();
    expect(await c.delete('s'), isFalse);
    verifyNever(() => sponsors.delete('s'));
  });
}
