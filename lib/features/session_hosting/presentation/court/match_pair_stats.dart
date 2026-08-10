import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// How evenly matched the two sides are.
///
/// Ports `MatchPairStats` on web. The number is a **display rank sum**, not a
/// level id sum — the ids are not in display order.
class MatchPairStats extends StatelessWidget {
  const MatchPairStats({
    required this.seats,
    required this.matchType,
    super.key,
  });

  /// Seat index → player, with gaps. Slots 0+1 are pair 1, 2+3 are pair 2.
  final List<SessionPlayer?> seats;
  final MatchType matchType;

  @override
  Widget build(BuildContext context) {
    final format = matchType == MatchType.singles
        ? CourtFormat.singles
        : CourtFormat.doubles;
    final balance = pairBalance([
      for (final player in seats) player?.level,
    ], format);

    // Nothing meaningful to compare until both sides have someone on them.
    if (balance == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Side(label: l10n.courtPair1, score: balance.pair1Score),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.courtPairGapLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
            Text(
              '${balance.scoreDifference}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                // A gap of 0-1 is a fair match; beyond that the host should
                // look again.
                color: balance.scoreDifference <= 1
                    ? palette.success
                    : palette.warning,
              ),
            ),
          ],
        ),
        _Side(label: l10n.courtPair2, score: balance.pair2Score),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$score',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
