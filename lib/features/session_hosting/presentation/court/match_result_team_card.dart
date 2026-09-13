import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// One side of the match, with its score box.
class MatchResultTeamCard extends StatelessWidget {
  const MatchResultTeamCard({
    required this.label,
    required this.players,
    required this.controller,
    required this.isWinner,
    required this.onTap,
    super.key,
  });

  final String label;
  final List<SessionPlayer> players;
  final TextEditingController controller;

  /// Drawn as the winner. Null-safe by construction: a draw clears both.
  final bool isWinner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      selected: isWinner,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            color: isWinner
                ? palette.success.withValues(alpha: 0.10)
                : palette.muted.withValues(alpha: 0.45),
            border: Border.all(
              color: isWinner ? palette.success : palette.border,
              width: isWinner ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // Icon plus border, never colour alone.
                  if (isWinner) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      AppIcons.trophy,
                      size: 16,
                      color: palette.success,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 36,
                child: Center(
                  child: Text(
                    players.map(l10n.playerName).join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.mutedForeground,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.matchResultScore,
                  hintText: '0',
                  floatingLabelAlignment: FloatingLabelAlignment.center,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
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
