import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_card_parts.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_list_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// One club row, shared by the "managing" and "joined" tabs.
///
/// Shows only what differs between rows: the role tag appears for moderators
/// alone (every row in a tab otherwise carries the same role), and the host
/// line is dropped when the host is the viewer. Tapping the card is the only
/// way in — the old "Manage ›" / "View ›" footer duplicated it.
class ClubListCard extends StatelessWidget {
  const ClubListCard({
    required this.club,
    required this.showHost,
    this.onTap,
    this.trailing,
    super.key,
  });

  final ClubSummary club;
  final bool showHost;
  final VoidCallback? onTap;

  /// The "..." menu on the managing tab; a chevron when null.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = clubPaletteOf(theme);
    final isPending = club.status == 'PENDING';
    final schedule = club.schedules.firstOrNull;
    final (contextIcon, contextText) = switch (club.defaultVenue?.name) {
      final String venue => (AppIcons.mapPin, venue),
      null when schedule != null => (
        AppIcons.clock,
        '${schedule.startTime}-${schedule.endTime}',
      ),
      _ => (null, null),
    };
    final tags = [
      if (club.role == 'MODERATOR')
        ClubTag(
          icon: AppIcons.shield,
          label: l10n.clubRoleModerator,
          color: palette.info,
        ),
      if (isPending)
        ClubTag(label: l10n.clubStatusPending, color: palette.warning),
    ];

    return ClubCardShell(
      onTap: isPending ? null : onTap,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          12,
          12,
          trailing == null ? 8 : 0,
          12,
        ),
        child: Row(
          children: [
            ClubListAvatar(name: club.name, imageUrl: club.heroImage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(spacing: 6, runSpacing: 4, children: tags),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      ClubMeta(
                        icon: AppIcons.users,
                        text: l10n.socialMemberCount(club.memberCount),
                      ),
                      if (contextIcon != null && contextText != null)
                        ClubMeta(icon: contextIcon, text: contextText),
                    ],
                  ),
                  if (showHost) ...[
                    const SizedBox(height: 2),
                    ClubMeta(
                      icon: AppIcons.user,
                      text: l10n.clubHostedBy(
                        club.hostName ?? l10n.clubNotSpecified,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: palette.mutedForeground,
                ),
          ],
        ),
      ),
    );
  }
}
