import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/session/session_data_cache.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';

void main() {
  test('invalidates account-specific notifier and family state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(clubsControllerProvider.notifier)
        .restore(const ClubsState(search: 'old clubs', page: 4));
    container
        .read(
          mySessionsControllerProvider(MySessionScope.hosted).notifier,
        )
        .restore(
          const MySessionsState(search: 'previous account', hasLoaded: true),
        );

    invalidateSessionData(container);

    expect(container.read(clubsControllerProvider).page, 0);
    expect(container.read(clubsControllerProvider).search, isEmpty);
    expect(
      container
          .read(mySessionsControllerProvider(MySessionScope.hosted))
          .search,
      isEmpty,
    );
    expect(
      container
          .read(mySessionsControllerProvider(MySessionScope.hosted))
          .hasLoaded,
      isFalse,
    );
  });
}
