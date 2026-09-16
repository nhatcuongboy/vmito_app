import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/roster/presentation/widgets/player_profile_form_sheet.dart';
import 'package:vmito_app/features/roster/presentation/widgets/player_profile_stats_sheet.dart';
import 'package:vmito_app/features/roster/presentation/widgets/promote_player_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/gender_icon.dart';

class PlayerProfileCard extends ConsumerWidget {
  const PlayerProfileCard({
    required this.profile,
    this.onChanged,
    super.key,
  });

  final PlayerProfile profile;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
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
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (profile.gender != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(genderIcon(profile.gender), size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (profile.level != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.levelName(profile.level!),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          _buildClubBadge(context),
                        ],
                      ),
                    ],
                  ),
                ),
                if (profile.isPromoted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.rosterStatusPromoted,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(AppIcons.moreHorizontal),
                  onSelected: (action) => _handleAction(context, ref, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'stats',
                      child: Row(
                        children: [
                          const Icon(AppIcons.trendingUp, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(l10n.rosterViewStats),
                        ],
                      ),
                    ),
                    if (profile.isActive)
                      PopupMenuItem(
                        value: 'promote',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_circle_up_rounded,
                              size: 20,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(l10n.rosterPromoteToUser),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(AppIcons.edit, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(l10n.commonEdit),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.delete,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l10n.commonDelete,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  context,
                  label: l10n.rosterTotalSessions,
                  value: '${profile.totalSessions}',
                ),
                _buildStatItem(
                  context,
                  label: l10n.rosterPoints,
                  value: '${profile.points}',
                ),
                _buildStatItem(
                  context,
                  label: l10n.rosterTier,
                  value: profile.tier,
                  isHighlight: true,
                ),
              ],
            ),
            if (profile.phone != null && profile.phone!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    profile.phone!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (profile.notes != null && profile.notes!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      profile.notes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClubBadge(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final clubName = profile.club?.name;

    if (clubName != null && clubName.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          clubName,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.rosterPersonalBadge,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'stats':
        await showPlayerProfileStatsSheet(context, profileId: profile.id);
      case 'promote':
        final promoted = await showPromotePlayerDialog(context, profile: profile);
        if (promoted == true) {
          onChanged?.call();
        }
      case 'edit':
        final updated = await showPlayerProfileFormSheet(context, profile: profile);
        if (updated == true) {
          onChanged?.call();
        }
      case 'delete':
        final confirmed = await showAppConfirmDialog(
          context,
          type: AppConfirmDialogType.destructive,
          title: l10n.rosterDeleteTitle,
          content: l10n.rosterDeleteConfirm(profile.name),
          confirmLabel: l10n.commonDelete,
        );
        if (confirmed == true) {
          final success = await ref
              .read(rosterControllerProvider.notifier)
              .deleteProfile(profile.id);
          if (context.mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.rosterDeleteSuccess)),
            );
            onChanged?.call();
          }
        }
    }
  }
}
