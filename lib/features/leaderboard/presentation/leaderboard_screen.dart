import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_controller.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard_periods.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_entries.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_period_controls.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_skeleton.dart';
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
    ref.listen(leaderboardControllerProvider, (previous, next) {
      if (next.error != null &&
          next.error != previous?.error &&
          next.entries.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.leaderboardLoadMoreError)),
        );
      }
    });

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
          child: RefreshIndicator(
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
                          onSelected: (period) => controller.load(
                            period: period,
                          ),
                        ),
                        if (state.period != LeaderboardPeriod.all) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _PeriodStatusRow(
                            period: state.period,
                            periodKey: state.periodKey,
                            periodEnd: state.periodEnd,
                            isCurrentPeriod: state.isCurrentPeriod,
                            onSelectPeriod: () => _showPeriodPicker(state),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ..._contentSlivers(
                  state: state,
                  currentUserId: currentUserId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contentSlivers({
    required LeaderboardState state,
    required String? currentUserId,
  }) {
    final l10n = AppLocalizations.of(context);
    if (state.isLoading && !state.hasLoaded) {
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          sliver: SliverToBoxAdapter(child: LeaderboardSkeleton()),
        ),
      ];
    }
    if (state.error != null && state.entries.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorView(
            error: state.error!,
            onRetry: ref.read(leaderboardControllerProvider.notifier).refresh,
          ),
        ),
      ];
    }
    if (state.entries.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _LeaderboardEmptyState(
            title: l10n.leaderboardEmptyTitle,
            description: l10n.leaderboardEmptyDescription,
          ),
        ),
      ];
    }

    final podium = state.entries.take(3).toList(growable: false);
    final rest = state.entries.skip(3).toList(growable: false);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: LeaderboardPodium(
            entries: podium,
            period: state.period,
            onTap: _openProfile,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          0,
        ),
        sliver: SliverList.separated(
          itemCount: rest.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final entry = rest[index];
            return LeaderboardRankRow(
              entry: entry,
              isMe: entry.user.id == currentUserId,
              onTap: () => _openProfile(entry),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: state.isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox(height: AppSpacing.lg),
        ),
      ),
    ];
  }

  void _openProfile(LeaderboardEntry entry) {
    unawaited(
      context.pushNamed(
        AppRoutes.namePublicProfile,
        pathParameters: {'id': entry.user.id},
      ),
    );
  }

  Future<void> _showPeriodPicker(LeaderboardState state) async {
    final options = recentLeaderboardPeriods(state.period);
    final selected = await showModalBottomSheet<LeaderboardPeriodOption>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  l10n.leaderboardPeriodPickerTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final option in options)
                ListTile(
                  key: ValueKey('leaderboard-period-option-${option.key}'),
                  onTap: () => Navigator.of(context).pop(option),
                  trailing: (state.periodKey ?? options.first.key) == option.key
                      ? Icon(
                          AppIcons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  title: Text(
                    periodOptionLabel(l10n, state.period, option),
                  ),
                ),
            ],
          ),
        );
      },
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

class _PeriodStatusRow extends StatelessWidget {
  const _PeriodStatusRow({
    required this.period,
    required this.periodKey,
    required this.periodEnd,
    required this.isCurrentPeriod,
    required this.onSelectPeriod,
  });

  final LeaderboardPeriod period;
  final String? periodKey;
  final DateTime? periodEnd;
  final bool isCurrentPeriod;
  final VoidCallback onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    final picker = LeaderboardPeriodButton(
      period: period,
      periodKey: periodKey,
      onTap: onSelectPeriod,
    );
    final countdown = LeaderboardCountdown(
      endsAt: periodEnd,
      isCurrent: isCurrentPeriod,
    );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          picker,
          const SizedBox(height: AppSpacing.xs),
          Align(alignment: Alignment.centerRight, child: countdown),
        ],
      );
    }
    return Row(
      children: [
        picker,
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: countdown),
      ],
    );
  }
}

class _LeaderboardEmptyState extends StatelessWidget {
  const _LeaderboardEmptyState({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: .06),
            border: Border.all(color: color.withValues(alpha: .18)),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.trophy, size: 40, color: color),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).extension<AppPalette>()!.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
