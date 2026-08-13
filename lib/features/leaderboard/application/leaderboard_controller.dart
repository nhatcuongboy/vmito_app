import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/leaderboard/data/repositories/ranking_repository_impl.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/repositories/ranking_repository.dart';

const leaderboardPageSize = 20;

class LeaderboardState {
  const LeaderboardState({
    this.period = LeaderboardPeriod.week,
    this.entries = const [],
    this.page = 0,
    this.totalPages = 1,
    this.isCurrentPeriod = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasLoaded = false,
    this.periodKey,
    this.periodEnd,
    this.error,
  });

  final LeaderboardPeriod period;
  final String? periodKey;
  final List<LeaderboardEntry> entries;
  final int page;
  final int totalPages;
  final DateTime? periodEnd;
  final bool isCurrentPeriod;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasLoaded;
  final Object? error;

  bool get hasMore => page < totalPages;

  LeaderboardState copyWith({
    LeaderboardPeriod? period,
    String? periodKey,
    bool clearPeriodKey = false,
    List<LeaderboardEntry>? entries,
    int? page,
    int? totalPages,
    DateTime? periodEnd,
    bool clearPeriodEnd = false,
    bool? isCurrentPeriod,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasLoaded,
    Object? error,
    bool clearError = false,
  }) => LeaderboardState(
    period: period ?? this.period,
    periodKey: clearPeriodKey ? null : periodKey ?? this.periodKey,
    entries: entries ?? this.entries,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    periodEnd: clearPeriodEnd ? null : periodEnd ?? this.periodEnd,
    isCurrentPeriod: isCurrentPeriod ?? this.isCurrentPeriod,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    error: clearError ? null : error ?? this.error,
  );
}

class LeaderboardController extends Notifier<LeaderboardState> {
  var _requestVersion = 0;

  RankingRepository get _repository => ref.read(rankingRepositoryProvider);

  @override
  LeaderboardState build() => const LeaderboardState();

  Future<void> load({
    LeaderboardPeriod? period,
    String? periodKey,
  }) async {
    final nextPeriod = period ?? state.period;
    final nextPeriodKey = nextPeriod == LeaderboardPeriod.all
        ? null
        : periodKey;
    final requestVersion = ++_requestVersion;
    state = LeaderboardState(
      period: nextPeriod,
      periodKey: nextPeriodKey,
      isLoading: true,
    );

    try {
      final result = await _repository.leaderboard(
        period: nextPeriod,
        periodKey: nextPeriodKey,
        page: 1,
        limit: leaderboardPageSize,
      );
      if (requestVersion != _requestVersion) return;
      state = LeaderboardState(
        period: nextPeriod,
        periodKey: nextPeriodKey,
        entries: result.entries,
        page: result.page,
        totalPages: result.totalPages,
        periodEnd: result.periodEnd,
        isCurrentPeriod: result.isCurrentPeriod,
        hasLoaded: true,
      );
    } on Object catch (error) {
      if (requestVersion != _requestVersion) return;
      state = LeaderboardState(
        period: nextPeriod,
        periodKey: nextPeriodKey,
        hasLoaded: true,
        error: error,
      );
    }
  }

  Future<void> refresh() => load(
    period: state.period,
    periodKey: state.periodKey,
  );

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final requestVersion = _requestVersion;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await _repository.leaderboard(
        period: state.period,
        periodKey: state.periodKey,
        page: nextPage,
        limit: leaderboardPageSize,
      );
      if (requestVersion != _requestVersion) return;
      final seen = state.entries.map((entry) => entry.user.id).toSet();
      final appended = result.entries.where(
        (entry) => seen.add(entry.user.id),
      );
      state = state.copyWith(
        entries: [...state.entries, ...appended],
        page: result.page,
        totalPages: result.totalPages,
        isLoadingMore: false,
        clearError: true,
      );
    } on Object catch (error) {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }
}

final leaderboardControllerProvider =
    NotifierProvider<LeaderboardController, LeaderboardState>(
      LeaderboardController.new,
    );
