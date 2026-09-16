import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/domain/player_profile_stats.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_full_height_modal.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_app/shared/widgets/gender_icon.dart';

Future<void> showPlayerProfileStatsSheet(
  BuildContext context, {
  required String profileId,
}) {
  return showAppFullHeightModal<void>(
    context,
    builder: (context) => _PlayerProfileStatsSheet(profileId: profileId),
  );
}

class _PlayerProfileStatsSheet extends ConsumerWidget {
  const _PlayerProfileStatsSheet({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(playerProfileStatsProvider(profileId));

    return Column(
      children: [
        AppSheetHeader(
          title: l10n.rosterPlayerStatsTitle,
          onClose: () => Navigator.pop(context),
        ),
        Expanded(
          child: statsAsync.when(
            data: (stats) => _StatsContent(stats: stats),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppErrorView(
              error: error,
              onRetry: () => ref.invalidate(playerProfileStatsProvider(profileId)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.stats});

  final PlayerProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final badmintonPoints = stats.badmintonPoints;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Player header
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    stats.name.isNotEmpty ? stats.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              stats.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (stats.gender != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(genderIcon(stats.gender), size: 16),
                          ],
                        ],
                      ),
                      if (stats.level != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.levelName(stats.level!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badmintonPoints != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badmintonPoints.tier,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${badmintonPoints.totalPoints} pts',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Overall Performance Summary Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rosterOverallPerformance,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCircle(
                      title: l10n.rosterWinRate,
                      value: '${stats.winRate}%',
                      color: stats.winRate >= 50
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    _StatColumn(
                      label: l10n.rosterTotalSessions,
                      value: '${stats.totalSessions}',
                    ),
                    _StatColumn(
                      label: l10n.rosterTotalMatches,
                      value: '${stats.totalMatches}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      '${l10n.rosterWins}: ${stats.wins}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${l10n.rosterLosses}: ${stats.losses}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${l10n.rosterDraws}: ${stats.draws}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Session History Header
        Text(
          l10n.rosterSessionHistory,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        if (stats.sessionHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                l10n.rosterNoSessionHistory,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...stats.sessionHistory.map(
            (session) => Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: ListTile(
                dense: true,
                title: Text(
                  session.sessionName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  session.startTime != null
                      ? Dates.dateOnly(session.startTime!)
                      : session.status,
                ),
                trailing: Text(
                  '${session.wins}W - ${session.losses}L'
                  '${session.draws > 0 ? ' - ${session.draws}D' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: session.wins >= session.losses
                        ? AppColors.success
                        : theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCircle extends StatelessWidget {
  const _StatCircle({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
