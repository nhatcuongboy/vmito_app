import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A tab that exists in the shell but has no feature behind it yet.
///
/// The shell's branch list is fixed at construction, so a destination cannot be
/// added later without touching routing. Reserving the slot now — visibly
/// empty — is cheaper and more honest than hiding the tab and rewiring later.
class AppPlaceholderScreen extends StatelessWidget {
  const AppPlaceholderScreen({
    required this.title,
    required this.icon,
    this.phase,
    super.key,
  });

  final String title;
  final IconData icon;

  /// Which roadmap phase builds this, e.g. `P2`. Shown in the UI so an
  /// internal build says what is missing rather than looking broken.
  final String? phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: palette.mutedForeground),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.comingSoon,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
              if (phase != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  phase!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
