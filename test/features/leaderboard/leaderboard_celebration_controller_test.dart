import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_celebration_controller.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_controller.dart';
import 'package:vmito_app/features/leaderboard/data/leaderboard_celebration_preferences.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

void main() {
  late _FakePreferences preferences;

  ProviderContainer container() {
    final created = ProviderContainer(
      overrides: [
        leaderboardCelebrationPreferencesProvider.overrideWithValue(
          preferences,
        ),
      ],
    );
    addTearDown(created.dispose);
    return created;
  }

  setUp(() => preferences = _FakePreferences());

  test('celebrates a top-3 finish on the current period', () async {
    final ref = container();
    await ref
        .read(leaderboardCelebrationControllerProvider.notifier)
        .evaluate(_board(rank: 1), 'me');

    final state = ref.read(leaderboardCelebrationControllerProvider);
    expect(state.isVisible, isTrue);
    expect(state.entry!.rank, 1);
    expect(preferences.stored, isNotNull);
  });

  test('does not celebrate the same period twice', () async {
    final ref = container();
    final controller = ref.read(
      leaderboardCelebrationControllerProvider.notifier,
    );
    await controller.evaluate(_board(rank: 2), 'me');
    controller.dismiss();
    await controller.evaluate(_board(rank: 2), 'me');

    expect(
      ref.read(leaderboardCelebrationControllerProvider).isVisible,
      isFalse,
    );
  });

  test('celebrates again when the rank improves', () async {
    final ref = container();
    final controller = ref.read(
      leaderboardCelebrationControllerProvider.notifier,
    );
    await controller.evaluate(_board(rank: 3), 'me');
    controller.dismiss();
    await controller.evaluate(_board(rank: 1), 'me');

    final state = ref.read(leaderboardCelebrationControllerProvider);
    expect(state.isVisible, isTrue);
    expect(state.entry!.rank, 1);
  });

  test('does not celebrate again when the rank drops', () async {
    final ref = container();
    final controller = ref.read(
      leaderboardCelebrationControllerProvider.notifier,
    );
    await controller.evaluate(_board(rank: 1), 'me');
    controller.dismiss();
    await controller.evaluate(_board(rank: 3), 'me');

    expect(
      ref.read(leaderboardCelebrationControllerProvider).isVisible,
      isFalse,
    );
  });

  // The whole reason the gate keys off `periodEnd`: `periodKey` stays null for
  // every current period, so it cannot tell this week from the next one.
  test('celebrates a new period even though periodKey is still null', () async {
    final ref = container();
    final controller = ref.read(
      leaderboardCelebrationControllerProvider.notifier,
    );
    await controller.evaluate(
      _board(rank: 1, periodEnd: DateTime.utc(2026, 9, 14)),
      'me',
    );
    controller.dismiss();
    await controller.evaluate(
      _board(rank: 1, periodEnd: DateTime.utc(2026, 9, 21)),
      'me',
    );

    expect(
      ref.read(leaderboardCelebrationControllerProvider).isVisible,
      isTrue,
    );
  });

  test('ignores ranks outside the top 3', () async {
    final ref = container();
    await ref
        .read(leaderboardCelebrationControllerProvider.notifier)
        .evaluate(_board(rank: 4), 'me');

    expect(
      ref.read(leaderboardCelebrationControllerProvider).isVisible,
      isFalse,
    );
    expect(preferences.stored, isNull);
  });

  test('ignores historical periods', () async {
    final ref = container();
    await ref
        .read(leaderboardCelebrationControllerProvider.notifier)
        .evaluate(_board(rank: 1, isCurrentPeriod: false), 'me');

    expect(
      ref.read(leaderboardCelebrationControllerProvider).isVisible,
      isFalse,
    );
  });

  test('ignores a signed-out viewer', () async {
    final ref = container();
    await ref
        .read(leaderboardCelebrationControllerProvider.notifier)
        .evaluate(_board(rank: 1), null);

    expect(
      ref.read(leaderboardCelebrationControllerProvider).isVisible,
      isFalse,
    );
  });

  test('still celebrates when the preferences store throws', () async {
    preferences = _FakePreferences(failing: true);
    final ref = container();
    await ref
        .read(leaderboardCelebrationControllerProvider.notifier)
        .evaluate(_board(rank: 1), 'me');

    expect(
      ref.read(leaderboardCelebrationControllerProvider).isVisible,
      isTrue,
    );
  });
}

LeaderboardState _board({
  required int rank,
  bool isCurrentPeriod = true,
  DateTime? periodEnd,
}) => LeaderboardState(
  entries: [
    for (var position = 1; position <= 4; position++)
      LeaderboardEntry(
        rank: position,
        points: 100 - position,
        user: LeaderboardUser(id: position == rank ? 'me' : 'u$position'),
        tier: RankingTier.gold,
        totalPoints: 1200,
        matchesWon: 4,
        matchesPlayed: 6,
      ),
  ],
  periodEnd: periodEnd ?? DateTime.utc(2026, 9, 14),
  isCurrentPeriod: isCurrentPeriod,
  hasLoaded: true,
);

class _FakePreferences implements LeaderboardCelebrationPreferences {
  _FakePreferences({this.failing = false});

  final bool failing;
  String? stored;

  @override
  Future<String?> readCelebrated() async {
    if (failing) throw StateError('store unavailable');
    return stored;
  }

  @override
  Future<void> writeCelebrated(String token) async {
    if (failing) throw StateError('store unavailable');
    stored = token;
  }
}
