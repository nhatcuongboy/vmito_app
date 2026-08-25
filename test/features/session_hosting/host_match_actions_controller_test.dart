import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/form/match_update_draft.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_match_actions_controller.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';

class _Repository extends Mock implements SessionRepository {}

class _DraftFake extends Fake implements MatchUpdateDraft {}

void main() {
  setUpAll(() => registerFallbackValue(_DraftFake()));

  const draft = MatchUpdateDraft(
    playerIds: ['p1', 'p2'],
    pair1PlayerIds: ['p1'],
    pair2PlayerIds: ['p2'],
    noResult: false,
    pair1Score: 21,
    pair2Score: 10,
    isExtra: false,
    notes: '',
  );

  test('prevents duplicate updates and refreshes result resources', () async {
    final repository = _Repository();
    final pending = Completer<void>();
    when(() => repository.matches('s1')).thenAnswer((_) async => const []);
    when(() => repository.byId('s1')).thenAnswer(
      (_) async => const Session(
        id: 's1',
        name: 'Session',
        status: SessionStatus.inProgress,
      ),
    );
    when(
      () => repository.playerStatistics('s1'),
    ).thenAnswer((_) async => const []);
    when(
      () => repository.updateMatch('m1', any()),
    ).thenAnswer((_) => pending.future);
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(matchHistoryProvider('s1').future);
    await container.read(sessionDetailProvider('s1').future);
    await container.read(playerStatisticsProvider('s1').future);
    final controller = container.read(
      hostMatchActionsControllerProvider('s1').notifier,
    );

    final first = controller.update('m1', draft);
    final duplicate = await controller.update('m1', draft);
    expect(duplicate, isFalse);
    expect(
      container.read(hostMatchActionsControllerProvider('s1')).isBusy('m1'),
      isTrue,
    );
    pending.complete();
    expect(await first, isTrue);
    await container.read(matchHistoryProvider('s1').future);
    await container.read(sessionDetailProvider('s1').future);
    await container.read(playerStatisticsProvider('s1').future);

    verify(() => repository.updateMatch('m1', draft)).called(1);
    verify(() => repository.matches('s1')).called(2);
    verify(() => repository.byId('s1')).called(2);
    verify(() => repository.playerStatistics('s1')).called(2);
  });

  test('stores failures and clears busy state', () async {
    final repository = _Repository();
    final error = StateError('failed');
    when(() => repository.deleteMatch('m1')).thenThrow(error);
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      hostMatchActionsControllerProvider('s1').notifier,
    );

    expect(await controller.delete('m1'), isFalse);

    final state = container.read(hostMatchActionsControllerProvider('s1'));
    expect(state.error, same(error));
    expect(state.isBusy('m1'), isFalse);
  });
}
