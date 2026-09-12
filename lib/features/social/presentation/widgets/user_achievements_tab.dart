import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/points_rules_sheet.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/rank_visuals.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/tier_badge.dart';
import 'package:vmito_app/features/social/application/achievement_share_service.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/presentation/widgets/user_achievements_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _achievementPeriods = ['week', 'month', 'year', 'all'];
const _wideRankGridBreakpoint = 520.0;
const _achievementContentMaxWidth = 760.0;

class UserAchievementsTab extends ConsumerStatefulWidget {
  const UserAchievementsTab({
    required this.userId,
    required this.profile,
    required this.isOwner,
    super.key,
  });

  final String userId;
  final PublicProfile profile;
  final bool isOwner;

  @override
  ConsumerState<UserAchievementsTab> createState() =>
      _UserAchievementsTabState();
}

class _UserAchievementsTabState extends ConsumerState<UserAchievementsTab> {
  late Future<UserAchievements> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(UserAchievementsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _future = _load();
  }

  Future<UserAchievements> _load() =>
      ref.read(profileTabsServiceProvider).achievements(widget.userId);

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserAchievements>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _AchievementLoadError(
          onRetry: () => setState(() {
            _future = _load();
          }),
        );
      }
      if (!snapshot.hasData) return const UserAchievementsSkeleton();
      return LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth
              .clamp(
                0,
                _achievementContentMaxWidth,
              )
              .toDouble();
          final rankColumns = contentWidth >= _wideRankGridBreakpoint ? 4 : 2;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              key: PageStorageKey('profile-achievements-${widget.userId}'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: _AchievementContent(
                      data: snapshot.data!,
                      profile: widget.profile,
                      isOwner: widget.isOwner,
                      rankColumns: rankColumns,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _AchievementLoadError extends StatelessWidget {
  const _AchievementLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.error,
            size: 48,
            color: _palette(context).mutedForeground,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppLocalizations.of(context).achievementLoadError,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh),
            label: Text(AppLocalizations.of(context).commonRetry),
          ),
        ],
      ),
    ),
  );
}

class _AchievementContent extends ConsumerWidget {
  const _AchievementContent({
    required this.data,
    required this.profile,
    required this.isOwner,
    required this.rankColumns,
  });

  final UserAchievements data;
  final PublicProfile profile;
  final bool isOwner;
  final int rankColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final transactions = data.recentTransactions.take(20).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AchievementHero(data: data, profile: profile),
        const SizedBox(height: AppSpacing.md),
        _RankGrid(data: data, columns: rankColumns),
        const SizedBox(height: AppSpacing.md),
        _StatsGrid(stats: data.stats),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (isOwner)
              OutlinedButton.icon(
                key: const ValueKey('achievement-share-card-button'),
                onPressed: () => unawaited(
                  showAchievementShareSheet(
                    context,
                    profile: profile,
                    achievements: data,
                  ),
                ),
                icon: const Icon(AppIcons.share),
                label: Text(l10n.achievementShareCard),
              ),
            OutlinedButton.icon(
              key: const ValueKey('achievement-view-leaderboard-button'),
              onPressed: () => context.goNamed(AppRoutes.nameLeaderboard),
              icon: const Icon(AppIcons.award),
              label: Text(l10n.leaderboardViewLeaderboard),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.achievementRecentPoints,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              key: const ValueKey('achievement-rules-button'),
              onPressed: () => unawaited(showPointsRulesSheet(context)),
              tooltip: l10n.leaderboardRulesTooltip,
              icon: const Icon(AppIcons.info),
            ),
          ],
        ),
        if (transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              l10n.achievementNoPointsYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _palette(context).mutedForeground,
              ),
            ),
          )
        else
          ...transactions.map((tx) => _TransactionTile(transaction: tx)),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _AchievementHero extends StatelessWidget {
  const _AchievementHero({required this.data, required this.profile});

  final UserAchievements data;
  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final visuals = tierVisualsFor(Theme.of(context).brightness, data.tier);
    final l10n = AppLocalizations.of(context);
    final progress = data.nextTier == null
        ? 1.0
        : (data.totalPoints / (data.totalPoints + data.nextTier!.pointsToNext))
              .clamp(0.0, 1.0);
    return Card(
      key: const ValueKey('achievement-hero'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: visuals.solid),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _AchievementAvatar(profile: profile, radius: 43),
            const SizedBox(height: AppSpacing.sm),
            EmojiSafeText(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            TweenAnimationBuilder<int>(
              key: const ValueKey('achievement-total-points'),
              tween: IntTween(begin: 0, end: data.totalPoints),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (context, value, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.leaderboardPointsUnit),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TierBadge(tier: data.tier),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.nextTier == null
                        ? l10n.achievementMaxTier
                        : l10n.achievementToNextTier(
                            data.nextTier!.pointsToNext,
                            tierLabel(l10n, data.nextTier!.tier),
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text('${(progress * 100).round()}%'),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(seconds: 1),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: visuals.solid,
                backgroundColor: _palette(context).muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankGrid extends StatelessWidget {
  const _RankGrid({required this.data, required this.columns});

  final UserAchievements data;
  final int columns;

  @override
  Widget build(BuildContext context) => _FixedGrid(
    key: ValueKey('achievement-rank-grid-$columns'),
    columns: columns,
    childAspectRatio: 1.45,
    children: [
      for (final period in _achievementPeriods)
        _RankCard(
          period: period,
          rank: data.ranks.where((rank) => rank.period == period).firstOrNull,
        ),
    ],
  );
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.period, required this.rank});

  final String period;
  final UserRank? rank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _OutlinedPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _periodLabel(l10n, period),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _palette(context).mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            rank?.rank == null ? '—' : l10n.achievementRank(rank!.rank!),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text('${rank?.points ?? 0} ${l10n.leaderboardPointsUnit}'),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final UserAchievementStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = [
      (l10n.achievementWins, stats.wins, AppColors.success),
      (l10n.achievementDraws, stats.draws, AppColors.warning),
      (l10n.achievementLosses, stats.losses, AppColors.destructive),
      (l10n.achievementMatchesPlayed, stats.matchesPlayed, null),
      (l10n.achievementTournamentTitles, stats.tournamentTitles, null),
      (
        l10n.achievementTournamentRunnerUps,
        stats.tournamentRunnerUps,
        null,
      ),
    ];
    return _FixedGrid(
      key: const ValueKey('achievement-stats-grid'),
      columns: 3,
      childAspectRatio: 1.2,
      children: [
        for (final value in values)
          _OutlinedPanel(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${value.$2}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: value.$3,
                  ),
                ),
                Text(
                  value.$1,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FixedGrid extends StatelessWidget {
  const _FixedGrid({
    required this.columns,
    required this.childAspectRatio,
    required this.children,
    super.key,
  });

  final int columns;
  final double childAspectRatio;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final child in children)
            SizedBox(
              width: width,
              height: width / childAspectRatio,
              child: child,
            ),
        ],
      );
    },
  );
}

class _OutlinedPanel extends StatelessWidget {
  const _OutlinedPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(
        color: _palette(context).border,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Padding(padding: const EdgeInsets.all(AppSpacing.sm), child: child),
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final PointTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.points >= 0;
    final palette = _palette(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _OutlinedPanel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievementReasonLabel(
                      AppLocalizations.of(context),
                      transaction.reason,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    Dates.dateOnly(
                      transaction.occurredAt,
                      locale: Localizations.localeOf(context).languageCode,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${positive ? '+' : ''}${transaction.points}',
              style: TextStyle(
                color: positive ? palette.success : AppColors.destructive,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementAvatar extends StatelessWidget {
  const _AchievementAvatar({required this.profile, required this.radius});

  final PublicProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      child: Text(
        _initials(profile.name),
        style: TextStyle(fontSize: radius * .55, fontWeight: FontWeight.w700),
      ),
    );
    final image = profile.image;
    if (image == null || image.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: image,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

Future<void> showAchievementShareSheet(
  BuildContext context, {
  required PublicProfile profile,
  required UserAchievements achievements,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _AchievementShareSheet(
    profile: profile,
    achievements: achievements,
  ),
);

class _AchievementShareSheet extends ConsumerStatefulWidget {
  const _AchievementShareSheet({
    required this.profile,
    required this.achievements,
  });

  final PublicProfile profile;
  final UserAchievements achievements;

  @override
  ConsumerState<_AchievementShareSheet> createState() =>
      _AchievementShareSheetState();
}

class _AchievementShareSheetState
    extends ConsumerState<_AchievementShareSheet> {
  final GlobalKey _captureKey = GlobalKey();
  var _sharing = false;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context).achievementShareCard,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: FittedBox(
                  alignment: Alignment.topCenter,
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: _AchievementShareCard(
                      profile: widget.profile,
                      data: widget.achievements,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('achievement-share-image-button'),
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.share),
              label: Text(
                AppLocalizations.of(context).achievementShareAction,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _captureKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final bytes = await ref
          .read(achievementCaptureServiceProvider)
          .capture(boundary);
      if (bytes == null || !mounted) return;
      final box = context.findRenderObject();
      final origin = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await ref
          .read(achievementShareServiceProvider)
          .sharePng(
            bytes,
            fileName:
                'ThanhTich-${widget.profile.id.substring(0, widget.profile.id.length > 8 ? 8 : widget.profile.id.length)}.png',
            origin: origin,
          );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).achievementShareError,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

class _AchievementShareCard extends StatelessWidget {
  const _AchievementShareCard({required this.profile, required this.data});

  final PublicProfile profile;
  final UserAchievements data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The share card always rasterizes on white, so it keeps the light tier.
    final visuals = tierVisualsFor(Brightness.light, data.tier);
    final shareStats = [
      (l10n.achievementWins, data.stats.wins),
      (l10n.achievementLosses, data.stats.losses),
      (l10n.achievementTournamentTitles, data.stats.tournamentTitles),
      (l10n.achievementMatchesPlayed, data.stats.matchesPlayed),
    ];
    return Material(
      color: Colors.white,
      child: SizedBox(
        key: const ValueKey('achievement-share-card-preview'),
        width: 540,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [visuals.solid, AppColors.brand],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.trophy, color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l10n.achievementCardBadge.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AchievementAvatar(profile: profile, radius: 44),
                    const SizedBox(height: AppSpacing.sm),
                    EmojiSafeText(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TierBadge(
                      tier: data.tier,
                      brightness: Brightness.light,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${data.totalPoints}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      l10n.leaderboardPointsUnit,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (
                    var index = 0;
                    index < _achievementPeriods.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ShareMetric(
                        label: _periodLabel(l10n, _achievementPeriods[index]),
                        value: switch (data.ranks
                            .where(
                              (rank) =>
                                  rank.period == _achievementPeriods[index],
                            )
                            .firstOrNull
                            ?.rank) {
                          final int rank => l10n.achievementRank(rank),
                          _ => '—',
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (var index = 0; index < shareStats.length; index++) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ShareMetric(
                        label: shareStats[index].$1,
                        value: '${shareStats[index].$2}',
                        accent: true,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Text(
                  l10n.achievementCardFooter,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF52525B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareMetric extends StatelessWidget {
  const _ShareMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    height: 78,
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: accent ? const Color(0xFFF0FDF4) : const Color(0xFFFAFAFA),
      border: Border.all(
        color: accent ? const Color(0xFFBBF7D0) : const Color(0xFFE4E4E7),
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: accent ? const Color(0xFF15803D) : const Color(0xFF18181B),
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF71717A), fontSize: 11),
        ),
      ],
    ),
  );
}

String _periodLabel(AppLocalizations l10n, String period) => switch (period) {
  'week' => l10n.leaderboardPeriodWeek,
  'month' => l10n.leaderboardPeriodMonth,
  'year' => l10n.achievementPeriodYear,
  _ => l10n.leaderboardPeriodAll,
};

String achievementReasonLabel(AppLocalizations l10n, String reason) =>
    switch (reason) {
      'SESSION_MATCH_WIN' => l10n.leaderboardReasonSessionWin,
      'SESSION_MATCH_DRAW' => l10n.leaderboardReasonSessionDraw,
      'SESSION_MATCH_LOSS' => l10n.leaderboardReasonSessionLoss,
      'SESSION_PARTICIPATION' => l10n.leaderboardReasonSessionParticipation,
      'TOURNAMENT_MATCH_WIN' => l10n.leaderboardReasonTournamentWin,
      'TOURNAMENT_MATCH_DRAW' => l10n.leaderboardReasonTournamentDraw,
      'TOURNAMENT_MATCH_LOSS' => l10n.leaderboardReasonTournamentLoss,
      'TOURNAMENT_CHAMPION' => l10n.leaderboardReasonTournamentChampion,
      'TOURNAMENT_RUNNER_UP' => l10n.leaderboardReasonTournamentRunnerUp,
      'TOURNAMENT_SEMIFINALIST' => l10n.leaderboardReasonTournamentSemifinalist,
      'ADJUSTMENT' => l10n.achievementReasonAdjustment,
      'SESSION_HOSTED' => l10n.achievementReasonSessionHosted,
      _ => _humanizeReason(reason),
    };

String _humanizeReason(String reason) {
  final words = reason
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part.toLowerCase())
      .toList();
  if (words.isEmpty) return reason;
  final first = words.first;
  words[0] = '${first[0].toUpperCase()}${first.substring(1)}';
  return words.join(' ');
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

AppPalette _palette(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ??
    (Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark()
        : AppPalette.light());
