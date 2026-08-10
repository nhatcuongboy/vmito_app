// `container.read` is called twice per test — once for the controller, once
// for the state it produced. Cascading them would discard the return values,
// which are the point.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/court/application/court_selection_controller.dart';
import 'package:vmito_app/features/court/application/court_selection_state.dart';
import 'package:vmito_app/features/court/data/repositories/court_repository_impl.dart';
import 'package:vmito_app/features/court/domain/match_result_draft.dart';
import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/features/court/domain/repositories/court_repository.dart';
import 'package:vmito_app/features/court/domain/suggested_players.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/pre_selected_slot.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _MockCourtRepository extends Mock implements CourtRepository {}

SessionPlayer waiting(String id, {int? number, int wait = 0, int? level}) =>
    SessionPlayer(
      id: id,
      name: 'Player $id',
      playerNumber: number,
      currentWaitTime: wait,
      level: level,
    );

Session sessionWith({
  CourtDirection direction = CourtDirection.horizontal,
  MatchType defaultMatchType = MatchType.doubles,
  List<SessionPlayer>? players,
  List<PreSelectedSlot> preSelected = const [],
}) => Session(
  id: 's1',
  name: 'Kèo test',
  status: SessionStatus.inProgress,
  defaultMatchType: defaultMatchType,
  courts: [
    Court(
      id: 'c1',
      courtNumber: 1,
      direction: direction,
      preSelectedPlayers: preSelected,
    ),
  ],
  players:
      players ??
      [
        waiting('a', number: 1, wait: 30),
        waiting('b', number: 2, wait: 20),
        waiting('c', number: 3, wait: 10),
        waiting('d', number: 4),
        waiting('e', number: 5),
      ],
);

const CourtSelectionKey key = (
  sessionId: 's1',
  courtId: 'c1',
  preSelect: false,
);

ProviderContainer containerFor(
  Session session, {
  CourtRepository? repository,
}) {
  final container = ProviderContainer(
    overrides: [
      sessionDetailProvider('s1').overrideWith((ref) => session),
      if (repository != null)
        courtRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  // The provider reads the session synchronously in `build`, so it has to have
  // resolved before the controller is first read.
  container.read(sessionDetailProvider('s1'));
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const MatchResultDraft());
    registerFallbackValue(MatchType.doubles);
  });

  group('picking by hand', () {
    test('starts on the session default with an empty court', () {
      final container = containerFor(sessionWith());
      final state = container.read(courtSelectionControllerProvider(key));

      expect(state.matchType, MatchType.doubles);
      expect(state.slots, [null, null, null, null]);
      expect(state.activeSlot, 0);
      expect(state.isComplete, isFalse);
    });

    test('a pick lands in the active seat and advances the cursor', () {
      final container = containerFor(sessionWith());
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      controller
        ..togglePlayer('a')
        ..togglePlayer('b');

      final state = container.read(courtSelectionControllerProvider(key));
      expect(state.slots, ['a', 'b', null, null]);
      expect(state.activeSlot, 2);
    });

    test('tapping a picked player again removes them', () {
      final container = containerFor(sessionWith());
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      controller
        ..togglePlayer('a')
        ..togglePlayer('b')
        ..togglePlayer('a');

      final state = container.read(courtSelectionControllerProvider(key));
      expect(state.slots, [null, 'b', null, null]);
      // The cursor parks on the seat just emptied, so a mis-tap is one tap
      // to fix rather than three.
      expect(state.activeSlot, 0);
    });

    test('the cursor wraps to the first gap, not past the end', () {
      final container = containerFor(sessionWith());
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      controller
        ..togglePlayer('a')
        ..togglePlayer('b')
        ..togglePlayer('c')
        ..togglePlayer('d')
        // Court full: clear seat 1, then pick again — it must land there.
        ..clearSlot(1)
        ..togglePlayer('e');

      final state = container.read(courtSelectionControllerProvider(key));
      expect(state.slots, ['a', 'e', 'c', 'd']);
      expect(state.isComplete, isTrue);
    });

    test('tapping an occupied seat on the court clears it', () {
      final container = containerFor(sessionWith());
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      controller
        ..togglePlayer('a')
        ..selectSlot(0);

      final state = container.read(courtSelectionControllerProvider(key));
      expect(state.slots.first, isNull);
      expect(state.activeSlot, 0);
    });

    test('switching to singles clears the picks and resizes the court', () {
      final container = containerFor(sessionWith());
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      controller
        ..togglePlayer('a')
        ..togglePlayer('b')
        // Keeping the first two would let the host confirm a pairing they
        // never chose for this format.
        ..setMatchType(MatchType.singles);

      final state = container.read(courtSelectionControllerProvider(key));
      expect(state.slots, [null, null]);
      expect(state.activeSlot, 0);
      expect(state.requiredCount, 2);
    });

    test('confirm sends nothing until every seat is filled', () {
      final container = containerFor(sessionWith());
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      controller
        ..togglePlayer('a')
        ..togglePlayer('b')
        ..togglePlayer('c');
      expect(controller.confirmationPayload(), isNull);

      controller.togglePlayer('d');
      expect(
        controller.confirmationPayload(),
        [
          const PlayerPosition(playerId: 'a', position: 0),
          const PlayerPosition(playerId: 'b', position: 1),
          const PlayerPosition(playerId: 'c', position: 2),
          const PlayerPosition(playerId: 'd', position: 3),
        ],
      );
    });
  });

  group('search', () {
    test('matches name and shirt number', () {
      final container = containerFor(
        sessionWith(
          players: [
            const SessionPlayer(id: 'a', name: 'An', playerNumber: 7),
            const SessionPlayer(id: 'b', name: 'Bình', playerNumber: 12),
          ],
        ),
      );
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      controller.setSearch('Bình');
      expect(controller.visiblePlayers.map((p) => p.id), ['b']);

      // A host calling "số 12" should not need to recall the name.
      controller.setSearch('12');
      expect(controller.visiblePlayers.map((p) => p.id), ['b']);

      controller.setSearch('   ');
      expect(controller.visiblePlayers, hasLength(2));
    });

    test('only WAITING players are offered, longest wait first', () {
      final container = containerFor(
        sessionWith(
          players: [
            const SessionPlayer(id: 'playing', status: PlayerStatus.playing),
            const SessionPlayer(id: 'ready', status: PlayerStatus.ready),
            waiting('short', wait: 2),
            waiting('long', wait: 40),
          ],
        ),
      );
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      expect(controller.waitingPlayers.map((p) => p.id), ['long', 'short']);
    });
  });

  group('server matchmaking', () {
    SuggestedPlayers suggestion(List<String> pair1, List<String> pair2) =>
        SuggestedPlayers(
          pair1: SuggestedPair(players: [for (final id in pair1) waiting(id)]),
          pair2: SuggestedPair(players: [for (final id in pair2) waiting(id)]),
        );

    test('seats the server pairs by column on a horizontal court', () async {
      final repository = _MockCourtRepository();
      when(
        () => repository.suggestedPlayers(
          any(),
          useAi: any(named: 'useAi'),
          language: any(named: 'language'),
          matchType: any(named: 'matchType'),
        ),
      ).thenAnswer((_) async => suggestion(['a', 'b'], ['c', 'd']));

      final container = containerFor(sessionWith(), repository: repository);
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      controller.setMode(CourtSelectionMode.auto);
      await controller.refreshSuggestion();

      // Horizontal: a team shares seats 0+1.
      expect(controller.confirmationPayload(), [
        const PlayerPosition(playerId: 'a', position: 0),
        const PlayerPosition(playerId: 'b', position: 1),
        const PlayerPosition(playerId: 'c', position: 2),
        const PlayerPosition(playerId: 'd', position: 3),
      ]);
    });

    test('a vertical court interleaves the pairs instead', () async {
      final repository = _MockCourtRepository();
      when(
        () => repository.suggestedPlayers(
          any(),
          useAi: any(named: 'useAi'),
          language: any(named: 'language'),
          matchType: any(named: 'matchType'),
        ),
      ).thenAnswer((_) async => suggestion(['a', 'b'], ['c', 'd']));

      final container = containerFor(
        sessionWith(direction: CourtDirection.vertical),
        repository: repository,
      );
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      await controller.refreshSuggestion();
      controller.setMode(CourtSelectionMode.auto);

      expect(controller.confirmationPayload(), [
        const PlayerPosition(playerId: 'a', position: 0),
        const PlayerPosition(playerId: 'b', position: 2),
        const PlayerPosition(playerId: 'c', position: 1),
        const PlayerPosition(playerId: 'd', position: 3),
      ]);
    });

    // The host can flip the AI switch faster than the model answers.
    test('a slow earlier response never overwrites a newer one', () async {
      final repository = _MockCourtRepository();
      final slow = Completer<SuggestedPlayers>();
      var call = 0;
      when(
        () => repository.suggestedPlayers(
          any(),
          useAi: any(named: 'useAi'),
          language: any(named: 'language'),
          matchType: any(named: 'matchType'),
        ),
      ).thenAnswer((_) {
        call++;
        return call == 1
            ? slow.future
            : Future.value(suggestion(['x', 'y'], ['z', 'w']));
      });

      final container = containerFor(sessionWith(), repository: repository);
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      final first = controller.refreshSuggestion();
      final second = controller.refreshSuggestion();
      await second;
      slow.complete(suggestion(['a', 'b'], ['c', 'd']));
      await first;

      final state = container.read(courtSelectionControllerProvider(key));
      expect(state.suggestion?.pair1.players.first.id, 'x');
      expect(state.isLoadingSuggestion, isFalse);
    });

    test('a failure is surfaced and leaves no stale suggestion', () async {
      final repository = _MockCourtRepository();
      when(
        () => repository.suggestedPlayers(
          any(),
          useAi: any(named: 'useAi'),
          language: any(named: 'language'),
          matchType: any(named: 'matchType'),
        ),
      ).thenThrow(StateError('not enough players'));

      final container = containerFor(sessionWith(), repository: repository);
      final controller = container.read(
        courtSelectionControllerProvider(key).notifier,
      );

      await controller.refreshSuggestion();

      final state = container.read(courtSelectionControllerProvider(key));
      expect(state.suggestionError, isA<StateError>());
      expect(state.suggestion, isNull);
      expect(state.isLoadingSuggestion, isFalse);
      expect(controller.confirmationPayload(), isNull);
    });

    test('the locale is passed through, not hardcoded to Vietnamese', () async {
      final repository = _MockCourtRepository();
      when(
        () => repository.suggestedPlayers(
          any(),
          useAi: any(named: 'useAi'),
          language: any(named: 'language'),
          matchType: any(named: 'matchType'),
        ),
      ).thenAnswer((_) async => suggestion(['a', 'b'], ['c', 'd']));

      final container = containerFor(sessionWith(), repository: repository);
      await container
          .read(courtSelectionControllerProvider(key).notifier)
          .refreshSuggestion();

      final captured = verify(
        () => repository.suggestedPlayers(
          'c1',
          useAi: any(named: 'useAi'),
          language: captureAny(named: 'language'),
          matchType: any(named: 'matchType'),
        ),
      ).captured;
      expect(captured.single, isA<String>());
    });
  });
}
