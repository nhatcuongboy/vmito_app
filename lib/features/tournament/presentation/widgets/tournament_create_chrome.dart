import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentCreateHero extends StatelessWidget {
  const TournamentCreateHero({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF08783E), Color(0xFF1FBD72)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0x33FFFFFF),
            foregroundColor: Colors.white,
            child: Icon(AppIcons.trophy),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tournamentCreateHeading,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.tournamentCreateIntro,
                  style: const TextStyle(color: Color(0xE6FFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TournamentCreateActionBar extends StatelessWidget {
  const TournamentCreateActionBar({
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: TournamentCreateActionButtons(
          isSubmitting: isSubmitting,
          onSubmit: onSubmit,
        ),
      ),
    ),
  );
}

class TournamentCreateActionButtons extends StatelessWidget {
  const TournamentCreateActionButtons({
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('tournament-submit-button'),
        onPressed: isSubmitting ? null : onSubmit,
        icon: isSubmitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(AppIcons.add),
        label: Text(
          isSubmitting
              ? l10n.tournamentCreateSubmitting
              : l10n.tournamentCreateSubmit,
        ),
      ),
    );
  }
}
