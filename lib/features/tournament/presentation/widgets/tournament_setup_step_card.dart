import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_setup_steps.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentSetupStepCard extends StatelessWidget {
  const TournamentSetupStepCard({
    required this.step,
    required this.number,
    required this.isDone,
    required this.isExpanded,
    required this.onToggle,
    required this.onAction,
    super.key,
  });

  final TournamentSetupStep step;
  final int number;
  final bool isDone;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (title, description, action) = _labels(l10n);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(
          color: isDone
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            onTap: onToggle,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isDone
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              foregroundColor: isDone
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
              child: isDone
                  ? const Icon(AppIcons.check, size: 16)
                  : Text('$number', style: const TextStyle(fontSize: 13)),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isDone ? scheme.onSurfaceVariant : null,
              ),
            ),
            trailing: Icon(
              isExpanded ? AppIcons.chevronUp : AppIcons.chevronDown,
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.tonal(onPressed: onAction, child: Text(action)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  (String, String, String) _labels(AppLocalizations l10n) => switch (step) {
    TournamentSetupStep.venue => (
      l10n.tournamentSetupStepVenueTitle,
      l10n.tournamentSetupStepVenueDescription,
      l10n.tournamentSetupStepVenueAction,
    ),
    TournamentSetupStep.categories => (
      l10n.tournamentSetupStepCategoriesTitle,
      l10n.tournamentSetupStepCategoriesDescription,
      l10n.tournamentSetupStepCategoriesAction,
    ),
    TournamentSetupStep.format => (
      l10n.tournamentSetupStepFormatTitle,
      l10n.tournamentSetupStepFormatDescription,
      l10n.tournamentSetupStepFormatAction,
    ),
    TournamentSetupStep.teams => (
      l10n.tournamentSetupStepTeamsTitle,
      l10n.tournamentSetupStepTeamsDescription,
      l10n.tournamentSetupStepTeamsAction,
    ),
    TournamentSetupStep.rounds => (
      l10n.tournamentSetupStepRoundsTitle,
      l10n.tournamentSetupStepRoundsDescription,
      l10n.tournamentSetupStepRoundsAction,
    ),
    TournamentSetupStep.schedule => (
      l10n.tournamentSetupStepScheduleTitle,
      l10n.tournamentSetupStepScheduleDescription,
      l10n.tournamentSetupStepScheduleAction,
    ),
    TournamentSetupStep.publish => (
      l10n.tournamentSetupStepPublishTitle,
      l10n.tournamentSetupStepPublishDescription,
      l10n.tournamentSetupStepPublishAction,
    ),
  };
}
