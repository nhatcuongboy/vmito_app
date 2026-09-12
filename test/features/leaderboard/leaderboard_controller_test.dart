import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_controller.dart';
import 'package:vmito_app/features/leaderboard/data/repositories/ranking_repository_impl.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/repositories/ranking_repository.dart';

void main() {
  test('load resets period and loadMore appends unique users', () async {
    final repository = _FakeRankingRepository();
    final container = ProviderContainer(
      overrides: [rankingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(leaderboardControllerProvider.notifier);

    await controller.load(
      period: LeaderboardPeriod.month,
      periodKey: '2026-07',
    );
    await controller.loadMore();

    final state = container.read(leaderboardControllerProvider);
    expect(state.period, LeaderboardPeriod.month);
    expect(state.periodKey, '2026-07');
    expect(state.page, 2);
    expect(state.entries.map((entry) => entry.user.id), ['u1', 'u2']);
  });

  test('does not start duplicate loadMore requests', () async {
    final repository = _FakeRankingRepository(delaySecondPage: true);
    final container = ProviderContainer(
      overrides: [rankingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(leaderboardControllerProvider.notifier);
    await controller.load();

    final first = controller.loadMore();
    final second = controller.loadMore();
    expect(repository.pageTwoCalls, 1);
    repository.secondPageCompleter.complete(_page(2, [_entry('u2', 21)]));
    await Future.wait([first, second]);
  });

  test('stale request cannot replace a newer period', () async {
    final repository = _StaleRankingRepository();
    final container = ProviderContainer(
      overrides: [rankingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(leaderboardControllerProvider.notifier);

    final old = controller.load(period: LeaderboardPeriod.week);
    final current = controller.load(period: LeaderboardPeriod.month);
    repository.month.complete(_page(1, [_entry('month', 1)]));
    await current;
    repository.week.complete(_page(1, [_entry('week', 1)]));
    await old;

    final state = container.read(leaderboardControllerProvider);
    expect(state.period, LeaderboardPeriod.month);
    expect(state.entries.single.user.id, 'month');
  });

  test('loadMore error preserves existing entries', () async {
    final repository = _FakeRankingRepository(failSecondPage: true);
    final container = ProviderContainer(
      overrides: [rankingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(leaderboardControllerProvider.notifier);
    await controller.load();
    await controller.loadMore();

    final state = container.read(leaderboardControllerProvider);
    expect(state.entries.single.user.id, 'u1');
    expect(state.error, isA<StateError>());
    expect(state.isLoadingMore, isFalse);
  });
}

class _FakeRankingRepository implements RankingRepository {
  _FakeRankingRepository({
    this.delaySecondPage = false,
    this.failSecondPage = false,
  });

  final bool delaySecondPage;
  final bool failSecondPage;
  final secondPageCompleter = Completer<LeaderboardPage>();
  int pageTwoCalls = 0;

  @override
  Future<LeaderboardPage> leaderboard({
    required LeaderboardPeriod period,
    required int page,
    required int limit,
    String? periodKey,
  }) async {
    if (page == 1) return _page(1, [_entry('u1', 1)], period: period);
    pageTwoCalls++;
    if (failSecondPage) throw StateError('page failed');
    if (delaySecondPage) return secondPageCompleter.future;
    return _page(2, [_entry('u1', 20), _entry('u2', 21)], period: period);
  }

  @override
  Future<MyLeaderboardRanks> myRanks() =>
      throw UnimplementedError('not used by these tests');
}

class _StaleRankingRepository implements RankingRepository {
  final week = Completer<LeaderboardPage>();
  final month = Completer<LeaderboardPage>();

  @override
  Future<LeaderboardPage> leaderboard({
    required LeaderboardPeriod period,
    required int page,
    required int limit,
    String? periodKey,
  }) => period == LeaderboardPeriod.week ? week.future : month.future;

  @override
  Future<MyLeaderboardRanks> myRanks() =>
      throw UnimplementedError('not used by these tests');
}

LeaderboardPage _page(
  int page,
  List<LeaderboardEntry> entries, {
  LeaderboardPeriod period = LeaderboardPeriod.week,
}) => LeaderboardPage(
  sport: 'BADMINTON',
  period: period,
  board: 'player',
  isCurrentPeriod: true,
  page: page,
  limit: 20,
  total: 2,
  totalPages: 2,
  entries: entries,
);

LeaderboardEntry _entry(String id, int rank) => LeaderboardEntry(
  rank: rank,
  points: 100 - rank,
  user: LeaderboardUser(id: id, name: id),
  tier: RankingTier.bronze,
  totalPoints: 100,
  matchesWon: 1,
  matchesPlayed: 2,
);
