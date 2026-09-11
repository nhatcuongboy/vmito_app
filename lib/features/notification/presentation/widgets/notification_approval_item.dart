import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/notification/domain/notification_panel_item.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SessionApprovalListItem extends StatelessWidget {
  const SessionApprovalListItem({
    required this.item,
    required this.busy,
    required this.onTap,
    required this.onDecision,
    super.key,
  });

  final SessionApprovalItem item;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final request = item.request;
    final name = request.playerName?.trim();
    return _ApprovalTile(
      key: ValueKey('session-approval-${request.id}'),
      accent: Colors.orange,
      itemId: request.id,
      name: name?.isNotEmpty ?? false ? name! : l10n.notificationUnknownPlayer,
      imageUrl: request.userImage,
      badge: l10n.notificationSessionRequestBadge,
      message: l10n.notificationSessionRequestMessage(
        request.sessionName.isEmpty
            ? l10n.notificationUnknownSession
            : request.sessionName,
      ),
      timestamp: request.createdAt ?? item.timestamp,
      suffix: item.slots.length > 1
          ? l10n.notificationSlotCount(item.slots.length)
          : null,
      busy: busy,
      onTap: onTap,
      onDecision: onDecision,
    );
  }
}

class ClubApprovalListItem extends StatelessWidget {
  const ClubApprovalListItem({
    required this.item,
    required this.busy,
    required this.onTap,
    required this.onDecision,
    super.key,
  });

  final ClubApprovalItem item;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final request = item.request;
    return _ApprovalTile(
      key: ValueKey('club-approval-${request.id}'),
      accent: Colors.blue,
      itemId: request.id,
      name: request.userName.isEmpty
          ? l10n.notificationUnknownPlayer
          : request.userName,
      imageUrl: request.userImage,
      badge: l10n.notificationClubRequestBadge,
      message: l10n.notificationClubRequestMessage(
        request.club?.name.isNotEmpty ?? false
            ? request.club!.name
            : l10n.notificationUnknownClub,
      ),
      timestamp: request.createdAt,
      busy: busy,
      onTap: onTap,
      onDecision: onDecision,
    );
  }
}

class VenueApprovalListItem extends StatelessWidget {
  const VenueApprovalListItem({
    required this.item,
    required this.onTap,
    super.key,
  });

  final VenueApprovalItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final request = item.request;
    const accent = Colors.purple;
    final submitter = request.submittedBy;
    final locale = Localizations.localeOf(context).languageCode;
    return _TintedTile(
      key: ValueKey('venue-approval-${request.id}'),
      accent: accent,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (submitter != null)
            PostAvatar(
              name: submitter.name,
              imageUrl: submitter.image,
              size: 44,
            )
          else
            const _FallbackIcon(accent: accent, icon: AppIcons.mapPin),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.displayName.isEmpty
                            ? l10n.notificationVenueRequestUntitled
                            : request.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _RequestBadge(
                      label: request.type == 'CREATE'
                          ? l10n.notificationVenueRequestCreateBadge
                          : l10n.notificationVenueRequestUpdateBadge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.notificationVenueRequestMessage(
                    submitter?.name ?? '-',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    height: 18 / 13,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.76 : 0.65,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Dates.timeAgo(request.createdAt, locale: locale),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    height: 16 / 12,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({
    required this.accent,
    required this.itemId,
    required this.name,
    required this.badge,
    required this.message,
    required this.busy,
    required this.onTap,
    required this.onDecision,
    this.timestamp,
    this.imageUrl,
    this.suffix,
    super.key,
  });

  final MaterialColor accent;
  final String itemId;
  final String name;
  final String? imageUrl;
  final String badge;
  final String message;
  final DateTime? timestamp;
  final String? suffix;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isDark = theme.brightness == Brightness.dark;
    return _TintedTile(
      accent: accent,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostAvatar(name: name, imageUrl: imageUrl, size: 44),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _RequestBadge(label: badge),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  suffix == null ? message : '$message · $suffix',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    height: 18 / 13,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: isDark ? 0.76 : 0.65,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timestamp != null)
                      Expanded(
                        child: Text(
                          Dates.timeAgo(timestamp!, locale: locale),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            height: 16 / 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: isDark ? 0.70 : 0.55,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        OutlinedButton(
                          key: ValueKey('reject-approval-$itemId'),
                          onPressed: busy ? null : () => onDecision(false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(76, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: isDark
                                ? const Color(0xFFF87171)
                                : Colors.red.shade700,
                            backgroundColor: Colors.transparent,
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFFF87171)
                                  : Colors.red.shade700,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            l10n.notificationReject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FilledButton(
                          key: ValueKey('approve-approval-$itemId'),
                          onPressed: busy ? null : () => onDecision(true),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(76, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isDark
                                ? AppColors.brandDark
                                : Colors.green.shade700,
                            foregroundColor: isDark
                                ? AppColors.primaryForegroundDark
                                : Colors.white,
                          ),
                          child: busy
                              ? SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark
                                        ? AppColors.primaryForegroundDark
                                        : Colors.white,
                                  ),
                                )
                              : Text(
                                  l10n.notificationApprove,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TintedTile extends StatelessWidget {
  const _TintedTile({
    required this.accent,
    required this.onTap,
    required this.child,
    super.key,
  });

  final MaterialColor accent;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: accent.withValues(alpha: dark ? 0.11 : 0.055),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ColoredBox(
                color: accent.shade400,
                child: const SizedBox(width: 4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestBadge extends StatelessWidget {
  const _RequestBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: isDark
            ? Colors.white.withValues(alpha: 0.70)
            : Colors.black.withValues(alpha: 0.55),
        fontWeight: FontWeight.w600,
      ),
    ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.accent, required this.icon});

  final MaterialColor accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: accent.withValues(alpha: 0.12),
      border: Border.all(color: accent.withValues(alpha: 0.2)),
    ),
    child: Icon(icon, size: 20, color: accent.shade500),
  );
}
