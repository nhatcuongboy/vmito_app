import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  test('shuttlecock feature flag falls back to false when API fails', () async {
    final repository = _MockSessionRepository();
    when(repository.showShuttlecockCount).thenThrow(Exception('offline'));
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final enabled = await container.read(showShuttlecockCountProvider.future);

    expect(enabled, isFalse);
  });
}
