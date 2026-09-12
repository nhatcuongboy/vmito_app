import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/tier_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

const _sessionRules = <int>[10, 5, 2, 5];
const _tournamentRules = <int>[20, 10, 5, 100, 60, 30];
const _tierThresholds = <RankingTier, int>{
  RankingTier.diamond: 10000,
  RankingTier.platinum: 4000,
  RankingTier.gold: 1500,
  RankingTier.silver: 500,
  RankingTier.bronze: 0,
};

Future<void> showPointsRulesSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _PointsRulesSheet(),
    );

class _PointsRulesSheet extends StatelessWidget {
  const _PointsRulesSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionLabels = [
      l10n.leaderboardReasonSessionWin,
      l10n.leaderboardReasonSessionDraw,
      l10n.leaderboardReasonSessionLoss,
      l10n.leaderboardReasonSessionParticipation,
    ];
    final tournamentLabels = [
      l10n.leaderboardReasonTournamentWin,
      l10n.leaderboardReasonTournamentDraw,
      l10n.leaderboardReasonTournamentLoss,
      l10n.leaderboardReasonTournamentChampion,
      l10n.leaderboardReasonTournamentRunnerUp,
      l10n.leaderboardReasonTournamentSemifinalist,
    ];
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(
              title: l10n.leaderboardRulesTitle,
              leadingIcon: AppIcons.trophy,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                children: [
                  Text(
                    l10n.leaderboardRulesIntro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).extension<AppPalette>()!.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RuleGroup(
                    title: l10n.leaderboardRulesSessionGroup,
                    children: [
                      for (var index = 0; index < _sessionRules.length; index++)
                        _RuleRow(
                          label: sessionLabels[index],
                          points: _sessionRules[index],
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RuleGroup(
                    title: l10n.leaderboardRulesTournamentGroup,
                    children: [
                      for (
                        var index = 0;
                        index < _tournamentRules.length;
                        index++
                      )
                        _RuleRow(
                          label: tournamentLabels[index],
                          points: _tournamentRules[index],
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RuleGroup(
                    title: l10n.leaderboardRulesTierGroup,
                    children: [
                      for (final entry in _tierThresholds.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Text(tierEmojiFor(context, entry.key)),
                              const SizedBox(width: AppSpacing.sm),
                              TierBadge(tier: entry.key),
                              const Spacer(),
                              Text(
                                l10n.leaderboardRulesFromPoints(entry.value),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .extension<AppPalette>()!
                                          .mutedForeground,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.leaderboardRulesNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).extension<AppPalette>()!.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleGroup extends StatelessWidget {
  const _RuleGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      ...children,
    ],
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.points});

  final String label;
  final int points;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Theme.of(context).extension<AppPalette>()!.border,
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '+$points',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}
