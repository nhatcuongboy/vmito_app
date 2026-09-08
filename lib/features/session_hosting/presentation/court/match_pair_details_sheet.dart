import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Shows the players, skill totals, and balance for the two sides on a court.
Future<void> showMatchPairDetailsSheet(
  BuildContext context, {
  required List<SessionPlayer?> seats,
  required MatchType matchType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => MatchPairDetailsSheet(seats: seats, matchType: matchType),
  );
}

class MatchPairDetailsSheet extends StatelessWidget {
  const MatchPairDetailsSheet({
    required this.seats,
    required this.matchType,
    super.key,
  });

  final List<SessionPlayer?> seats;
  final MatchType matchType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = matchType == MatchType.singles
        ? CourtFormat.singles
        : CourtFormat.doubles;
    final balance = pairBalance([
      for (final player in seats) player?.level,
    ], format);
    final pairSize = matchType == MatchType.singles ? 1 : 2;
    final firstPair = seats.take(pairSize);
    final secondPair = seats.skip(pairSize).take(pairSize);
    final hasCompleteLineup =
        seats.length >= pairSize * 2 &&
        seats.take(pairSize * 2).every((it) => it != null);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.courtPairDetails,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _PairSection(
              title: l10n.courtPair1,
              players: firstPair,
              score: hasCompleteLineup ? balance?.pair1Score : null,
            ),
            const SizedBox(height: AppSpacing.md),
            _PairSection(
              title: l10n.courtPair2,
              players: secondPair,
              score: hasCompleteLineup ? balance?.pair2Score : null,
            ),
            const SizedBox(height: AppSpacing.md),
            _BalanceSummary(balance: hasCompleteLineup ? balance : null),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairSection extends StatelessWidget {
  const _PairSection({
    required this.title,
    required this.players,
    required this.score,
  });

  final String title;
  final Iterable<SessionPlayer?> players;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.muted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${l10n.courtPairTotal}: ${score ?? '—'}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final player in players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Text(
                  player == null
                      ? l10n.courtPairEmptySlot
                      : '${l10n.playerName(player)} · '
                            '${player.level == null ? '—' : l10n.levelName(player.level!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: player == null ? palette.mutedForeground : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.balance});

  final PairBalance? balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    if (balance == null) {
      return Text(
        l10n.courtPairBalanceUnavailable,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.mutedForeground,
        ),
      );
    }

    return Row(
      children: [
        Text(l10n.courtPairGapLabel, style: theme.textTheme.titleSmall),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${balance!.scoreDifference}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: balance!.scoreDifference <= 1
                ? palette.success
                : palette.warning,
          ),
        ),
      ],
    );
  }
}
