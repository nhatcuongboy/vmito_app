import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

enum HostTournamentsEmptyKind { noResults, host, admin }

/// Empty state of the host list. A scrollable [ListView] so pull-to-refresh
/// still works when there is nothing to show.
class HostTournamentsEmptyView extends StatelessWidget {
  const HostTournamentsEmptyView({
    required this.kind,
    this.onCreate,
    super.key,
  });

  final HostTournamentsEmptyKind kind;

  /// Shown only on the host variant, for users allowed to create.
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final (title, description) = switch (kind) {
      HostTournamentsEmptyKind.noResults => (
        l10n.hostTournamentsNoResultsTitle,
        l10n.hostTournamentsNoResultsDesc,
      ),
      HostTournamentsEmptyKind.host => (
        l10n.hostTournamentsEmptyTitle,
        l10n.hostTournamentsEmptyDesc,
      ),
      HostTournamentsEmptyKind.admin => (
        l10n.hostTournamentsAdminEmptyTitle,
        l10n.hostTournamentsAdminEmptyDesc,
      ),
    };
    return ListView(
      key: const Key('host-tournaments-empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl * 2,
      ),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.brandSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              AppIcons.trophy,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          description,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
        if (kind == HostTournamentsEmptyKind.host && onCreate != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(AppIcons.add),
              label: Text(l10n.hostTournamentsCreateFirst),
            ),
          ),
        ],
      ],
    );
  }
}
