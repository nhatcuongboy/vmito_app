import 'package:flutter/material.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Explains MVP eligibility and ranking order for the player stats table.
Future<void> showPlayerStatisticsRankingInfoSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.hostPlayerStatsRankingTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.hostPlayerStatsEligibilityTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(l10n.hostPlayerStatsEligibility),
            const SizedBox(height: 18),
            Text(
              l10n.hostPlayerStatsOrderTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(l10n.hostPlayerStatsOrder),
            const SizedBox(height: 12),
            Text(
              l10n.hostPlayerStatsPointDiffHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
