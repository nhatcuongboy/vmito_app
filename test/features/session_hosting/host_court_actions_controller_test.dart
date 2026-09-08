import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/court/data/repositories/court_repository_impl.dart';
import 'package:vmito_app/features/court/domain/repositories/court_repository.dart';
import 'package:vmito_app/features/session_hosting/application/host_court_actions_controller.dart';
import 'package:vmito_app/features/session_hosting/application/host_court_actions_state.dart';

class _CourtRepository extends Mock implements CourtRepository {}

void main() {
  group('HostCourtActionsController', () {
    test(
      'tracks the active action and prevents duplicate submissions',
      () async {
        final repository = _CourtRepository();
        final pending = Completer<void>();
        when(() => repository.startMatch('court-1')).thenAnswer(
          (_) => pending.future,
        );
        final container = ProviderContainer(
          overrides: [courtRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          hostCourtActionsControllerProvider('session-1').notifier,
        );

        final first = controller.startMatch('court-1');

        expect(
          container
              .read(hostCourtActionsControllerProvider('session-1'))
              .activeActionFor('court-1'),
          HostCourtAction.start,
        );
        expect(await controller.startMatch('court-1'), isFalse);
        verify(() => repository.startMatch('court-1')).called(1);

        pending.complete();

        expect(await first, isTrue);
        expect(
          container
              .read(hostCourtActionsControllerProvider('session-1'))
              .activeActionFor('court-1'),
          isNull,
        );
      },
    );

    test(
      'keeps a failure associated with its court and clears loading',
      () async {
        final repository = _CourtRepository();
        final error = StateError('failed');
        when(() => repository.startMatch('court-2')).thenThrow(error);
        final container = ProviderContainer(
          overrides: [courtRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final succeeded = await container
            .read(hostCourtActionsControllerProvider('session-1').notifier)
            .startMatch('court-2');
        final state = container.read(
          hostCourtActionsControllerProvider('session-1'),
        );

        expect(succeeded, isFalse);
        expect(state.activeActionFor('court-2'), isNull);
        expect(state.failure?.courtId, 'court-2');
        expect(state.failure?.error, same(error));
      },
    );
  });
}
