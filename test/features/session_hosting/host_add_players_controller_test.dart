import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session_hosting/application/host_add_players_controller.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _Repository extends Mock implements SessionRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  test('prevents duplicate bulk submits while the first is pending', () async {
    final repository = _Repository();
    final pending = Completer<void>();
    when(
      () => repository.createPlayers(any(), any()),
    ).thenAnswer((_) => pending.future);
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      hostAddPlayersControllerProvider('s1').notifier,
    );
    const draft = HostPlayerDraft(
      name: 'Linh',
      phone: '',
      gender: Gender.female,
      level: 5,
      levelDescription: '',
      clubFeeEnabled: false,
    );

    final first = controller.submit(const [draft]);
    final second = await controller.submit(const [draft]);

    expect(second, isFalse);
    expect(
      container.read(hostAddPlayersControllerProvider('s1')).submitting,
      isTrue,
    );
    verify(() => repository.createPlayers('s1', any())).called(1);

    pending.complete();
    expect(await first, isTrue);
  });

  test('keeps the submission error available for inline feedback', () async {
    final repository = _Repository();
    final failure = StateError('bulk failed');
    when(
      () => repository.createPlayers(any(), any()),
    ).thenThrow(failure);
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      hostAddPlayersControllerProvider('s1').notifier,
    );
    const draft = HostPlayerDraft(
      name: 'Linh',
      phone: '',
      gender: Gender.female,
      level: 5,
      levelDescription: '',
      clubFeeEnabled: false,
    );

    expect(await controller.submit(const [draft]), isFalse);

    final state = container.read(hostAddPlayersControllerProvider('s1'));
    expect(state.submitting, isFalse);
    expect(state.error, same(failure));
  });
}
