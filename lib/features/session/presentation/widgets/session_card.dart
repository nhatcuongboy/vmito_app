import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/level_range_chips.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// One session in the browse list.
///
/// Horizontal, matching the web's mobile layout: the cover sits on the left so
/// the text column carries the two fields a player actually decides on — the
/// **skill band** and the **price**. A vertical card with a full-width cover
/// pushes both below the fold.
///
/// `BaseSessionCard` on web is 1,482 lines because it serves every context at
/// once. This is the browse card only.
enum _MoreAction { clone, downloadImage, share, delete }

class SessionCard extends StatelessWidget {
  const SessionCard({
    required this.session,
    this.onTap,
    this.onHost,
    this.onClone,
    this.onDownloadImage,
    this.onShare,
    this.onDelete,
    super.key,
  });

  final Session session;
  final VoidCallback? onTap;
  final VoidCallback? onHost;
  final VoidCallback? onClone;
  final VoidCallback? onDownloadImage;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  static const _coverWidth = 108.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final showActions =
        onHost != null ||
        onClone != null ||
        onDownloadImage != null ||
        onShare != null ||
        onDelete != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cover(session: session, width: _coverWidth),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (session.displayHostName.isNotEmpty)
                        _HostLine(session: session),
                      if (session.timeRangeLabel case final time?)
                        _MetaLine(
                          icon: AppIcons.clock,
                          text: time,
                          color: palette.warning,
                        ),
                      if (session.displayPlace.isNotEmpty)
                        _MetaLine(
                          icon: AppIcons.location,
                          text: session.displayPlace,
                          trailing: session.distance == null
                              ? null
                              : '${session.distance!.toStringAsFixed(1)} km',
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: LevelRangeChips(
                              requiredLevels: session.requiredLevels,
                            ),
                          ),
                          if (session.priceLabel case final price?)
                            Text(
                              price,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      if (showActions) ...[
                        const SizedBox(height: AppSpacing.xs + 2),
                        Container(
                          padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: palette.border),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (onHost != null)
                                FilledButton.icon(
                                  key: ValueKey(
                                    'session-host-button-${session.id}',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 34),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(AppIcons.settings, size: 16),
                                  label: const Text(
                                    'Host',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: onHost,
                                ),
                              const SizedBox(width: AppSpacing.xs),
                              PopupMenuButton<_MoreAction>(
                                key: ValueKey(
                                  'session-more-button-${session.id}',
                                ),
                                style: ButtonStyle(
                                  padding: WidgetStateProperty.all(
                                    EdgeInsets.zero,
                                  ),
                                  minimumSize: WidgetStateProperty.all(
                                    const Size(34, 34),
                                  ),
                                ),
                                icon: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: palette.border),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  child: const Icon(AppIcons.moreVert, size: 18),
                                ),
                                itemBuilder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return [
                                  PopupMenuItem(
                                    value: _MoreAction.clone,
                                    child: Row(
                                      children: [
                                        const Icon(AppIcons.copy, size: 18),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(l10n.mySessionsClone),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _MoreAction.downloadImage,
                                    child: Row(
                                      children: [
                                        const Icon(AppIcons.download, size: 18),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(l10n.mySessionsDownloadImage),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _MoreAction.share,
                                    child: Row(
                                      children: [
                                        const Icon(AppIcons.share, size: 18),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(l10n.mySessionsShare),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _MoreAction.delete,
                                    child: Builder(
                                      builder: (context) {
                                        final errorColor = Theme.of(
                                          context,
                                        ).colorScheme.error;
                                        return Row(
                                          children: [
                                            Icon(
                                              AppIcons.delete,
                                              size: 18,
                                              color: errorColor,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Text(
                                              l10n.mySessionsDelete,
                                              style: TextStyle(
                                                color: errorColor,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ];
                              },
                              onSelected: (action) => switch (action) {
                                _MoreAction.clone => onClone?.call(),
                                _MoreAction.downloadImage =>
                                  onDownloadImage?.call(),
                                _MoreAction.share => onShare?.call(),
                                _MoreAction.delete => onDelete?.call(),
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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

class _SlotsBadge extends StatelessWidget {
  const _SlotsBadge({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    if (session.status == SessionStatus.finished) {
      return Container(
        key: const Key('session-finished-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
        ),
        child: Text(
          l10n.mySessionsEnded,
          style: theme.textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final slots = session.availableSlots ?? 0;
    final closed = !session.status.isOpen;
    final full = slots == 0;
    final label = closed
        ? l10n.sessionRegistrationClosed
        : full
        ? l10n.sessionSlotsFull
        : l10n.sessionSlotsLeft(slots);
    final color = closed || full ? palette.mutedForeground : palette.success;
    return Container(
      key: const Key('session-slots-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.session, required this.width});

  final Session session;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final url = session.coverPhoto?.trim().isNotEmpty ?? false
        ? session.coverPhoto!.trim()
        : Session.defaultCoverPhoto;

    return SizedBox(
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, _) => ColoredBox(color: palette.muted),
            errorWidget: (context, _, _) => _Placeholder(palette: palette),
          ),
          if (session.availableSlots != null ||
              session.status == SessionStatus.finished)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _SlotsBadge(session: session),
            ),
          if (session.isCrawled)
            Positioned(
              bottom: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _CrawledBadge(source: session.externalSource),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.muted,
      child: Icon(
        AppIcons.sessions,
        color: palette.mutedForeground,
      ),
    );
  }
}

/// Marks a session imported from a public Facebook post — view-only, with no
/// host account behind it.
class _CrawledBadge extends StatelessWidget {
  const _CrawledBadge({this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        'Facebook',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HostLine extends StatelessWidget {
  const _HostLine({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final image = session.host?.image;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: palette.muted,
            foregroundImage: image == null || image.isEmpty
                ? null
                : CachedNetworkImageProvider(image),
            child: Icon(
              AppIcons.profile,
              size: 11,
              color: palette.mutedForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(
              session.displayHostName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String text;
  final String? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final tint = color ?? palette.mutedForeground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: tint),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}
