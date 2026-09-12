import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_celebration_controller.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_controller.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/celebration/leaderboard_celebration_sheet.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_my_rank_bar.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_period_picker_sheet.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_period_status_row.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_period_tabs.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_slivers.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/points_rules_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({
    this.initialPeriod = LeaderboardPeriod.week,
    this.initialPeriodKey,
    super.key,
  });

  final LeaderboardPeriod initialPeriod;
  final String? initialPeriodKey;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _scrollController = ScrollController();
  final GlobalKey _myRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(leaderboardControllerProvider.notifier)
            .load(
              period: widget.initialPeriod,
              periodKey: widget.initialPeriodKey,
            ),
      ),
    );
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 360) {
      unawaited(
        ref.read(leaderboardControllerProvider.notifier).loadMore(),
      );
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(leaderboardControllerProvider);
    final controller = ref.read(leaderboardControllerProvider.notifier);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    ref
      ..listen(leaderboardControllerProvider, (previous, next) {
        if (next.error != null &&
            next.error != previous?.error &&
            next.entries.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.leaderboardLoadMoreError)),
          );
        }
        unawaited(
          ref
              .read(leaderboardCelebrationControllerProvider.notifier)
              .evaluate(next, currentUserId),
        );
      })
      ..listen(leaderboardCelebrationControllerProvider, (previous, next) {
        final entry = next.entry;
        if (entry == null || previous?.entry == entry) return;
        unawaited(_celebrate(entry));
      });

    final myEntry = _myEntry(state, currentUserId);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(AppRoutes.nameHome);
            }
          },
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(AppIcons.arrowBack),
        ),
        title: Text(l10n.leaderboardTitle),
        actions: [
          IconButton(
            key: const ValueKey('leaderboard-rules-button'),
            onPressed: () => showPointsRulesSheet(context),
            tooltip: l10n.leaderboardRulesTooltip,
            icon: const Icon(AppIcons.help),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: controller.refresh,
                child: CustomScrollView(
                  key: const PageStorageKey('leaderboard-scroll'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        AppSpacing.sm,
                        AppSpacing.screenPadding,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LeaderboardPeriodTabs(
                              selected: state.period,
                              onSelected: (period) =>
                                  controller.load(period: period),
                            ),
                            if (state.period != LeaderboardPeriod.all) ...[
                              const SizedBox(height: AppSpacing.xs + 2),
                              LeaderboardPeriodStatusRow(
                                period: state.period,
                                periodKey: state.periodKey,
                                periodEnd: state.periodEnd,
                                isCurrentPeriod: state.isCurrentPeriod,
                                onSelectPeriod: () => _pickPeriod(state),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    ...leaderboardContentSlivers(
                      context,
                      state: state,
                      currentUserId: currentUserId,
                      myRowKey: _myRowKey,
                      onRetry: controller.refresh,
                      onOpenProfile: _openProfile,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: state.entries.isEmpty
                    ? const SizedBox.shrink()
                    : LeaderboardMyRankBar(
                        loadedEntry: myEntry,
                        period: state.period,
                        isCurrentPeriod: state.isCurrentPeriod,
                        onTap: myEntry == null || myEntry.rank <= 3
                            ? null
                            : () => _scrollToMyRow(state, myEntry),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LeaderboardEntry? _myEntry(LeaderboardState state, String? currentUserId) {
    if (currentUserId == null) return null;
    for (final entry in state.entries) {
      if (entry.user.id == currentUserId) return entry;
    }
    return null;
  }

  Future<void> _celebrate(LeaderboardEntry entry) async {
    if (!mounted) return;
    await showLeaderboardCelebration(context, entry: entry);
    if (!mounted) return;
    ref.read(leaderboardCelebrationControllerProvider.notifier).dismiss();
  }

  /// Two-step because the row may not be built yet in the lazy sliver: jump
  /// proportionally first, then refine once the row has a context.
  void _scrollToMyRow(LeaderboardState state, LeaderboardEntry entry) {
    final rest = state.entries.length - 3;
    final index = state.entries.indexOf(entry) - 3;
    if (rest <= 0 || index < 0) return;
    final position = _scrollController.position;
    unawaited(
      _scrollController.animateTo(
        (position.maxScrollExtent * index / rest).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowContext = _myRowKey.currentContext;
      if (rowContext == null || !mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.4,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _openProfile(LeaderboardEntry entry) {
    unawaited(
      context.pushNamed(
        AppRoutes.namePublicProfile,
        pathParameters: {'id': entry.user.id},
      ),
    );
  }

  Future<void> _pickPeriod(LeaderboardState state) async {
    final selected = await showLeaderboardPeriodPicker(
      context,
      period: state.period,
      periodKey: state.periodKey,
    );
    if (selected == null || !mounted) return;
    await ref
        .read(leaderboardControllerProvider.notifier)
        .load(
          period: state.period,
          periodKey: selected.isCurrent ? null : selected.key,
        );
  }
}
