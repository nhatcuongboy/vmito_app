import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/application/favorite_controller.dart';
import 'package:vmito_app/features/favorite/data/favorite_repository.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';

class _FakeFavoriteRepository implements FavoriteRepository {
  _FakeFavoriteRepository({this.summaryResult = const FavoriteSummary()});

  FavoriteSummary summaryResult;
  bool failWrites = false;
  int summaryCalls = 0;
  final calls = <String>[];

  @override
  Future<FavoriteSummary> summary(FavoriteType type, String targetId) async {
    summaryCalls++;
    return summaryResult;
  }

  @override
  Future<void> add(FavoriteType type, String targetId) async {
    calls.add('add');
    if (failWrites) throw StateError('boom');
  }

  @override
  Future<void> remove(FavoriteType type, String targetId) async {
    calls.add('remove');
    if (failWrites) throw StateError('boom');
  }
}

const FavoriteTarget _target = (type: FavoriteType.session, id: 's1');

ProviderContainer _container(
  _FakeFavoriteRepository repository, {
  bool signedIn = true,
}) {
  final container = ProviderContainer(
    overrides: [
      favoriteRepositoryProvider.overrideWithValue(repository),
      isSignedInProvider.overrideWithValue(signedIn),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('signed out: reports an empty summary without calling the API', () async {
    final repository = _FakeFavoriteRepository();
    final container = _container(repository, signedIn: false);

    final summary = await container.read(
      favoriteControllerProvider(_target).future,
    );

    expect(summary, const FavoriteSummary());
    expect(repository.summaryCalls, 0);
  });

  test('signed out: toggle reports false so the caller can prompt', () async {
    final repository = _FakeFavoriteRepository();
    final container = _container(repository, signedIn: false);
    await container.read(favoriteControllerProvider(_target).future);

    final signedIn = await container
        .read(favoriteControllerProvider(_target).notifier)
        .toggle();

    expect(signedIn, isFalse);
    expect(repository.calls, isEmpty);
  });

  test('toggle flips optimistically and persists', () async {
    final repository = _FakeFavoriteRepository(
      summaryResult: const FavoriteSummary(favoriteCount: 4),
    );
    final container = _container(repository);
    await container.read(favoriteControllerProvider(_target).future);

    await container
        .read(favoriteControllerProvider(_target).notifier)
        .toggle();

    final state = container.read(favoriteControllerProvider(_target)).value!;
    expect(state.isFavorite, isTrue);
    expect(state.favoriteCount, 5);
    expect(repository.calls, ['add']);
  });

  test('un-favoriting decrements and never goes negative', () async {
    // A stale zero from the server plus a local un-favorite would otherwise
    // render -1 for the rest of the session.
    final repository = _FakeFavoriteRepository(
      summaryResult: const FavoriteSummary(isFavorite: true),
    );
    final container = _container(repository);
    await container.read(favoriteControllerProvider(_target).future);

    await container
        .read(favoriteControllerProvider(_target).notifier)
        .toggle();

    final state = container.read(favoriteControllerProvider(_target)).value!;
    expect(state.isFavorite, isFalse);
    expect(state.favoriteCount, 0);
    expect(repository.calls, ['remove']);
  });

  test('a failed write rethrows and re-reads from the server', () async {
    final repository = _FakeFavoriteRepository(
      summaryResult: const FavoriteSummary(favoriteCount: 4),
    )..failWrites = true;
    final container = _container(repository);
    await container.read(favoriteControllerProvider(_target).future);
    expect(repository.summaryCalls, 1);

    await expectLater(
      container.read(favoriteControllerProvider(_target).notifier).toggle(),
      throwsA(isA<StateError>()),
    );

    // Re-read rather than a local rollback: the server is the authority.
    final restored = await container.read(
      favoriteControllerProvider(_target).future,
    );
    expect(repository.summaryCalls, 2);
    expect(restored.isFavorite, isFalse);
    expect(restored.favoriteCount, 4);
  });
}
