import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
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

class SessionCard extends ConsumerWidget {
  const SessionCard({
    required this.session,
    this.onTap,
    this.onHost,
    this.onClone,
    this.onDownloadImage,
    this.onShare,
    this.onDelete,
    this.compactStatusBadge = false,
    this.showFavorite = false,
    this.hideHostInfo = false,
    super.key,
  });

  final Session session;
  final VoidCallback? onTap;
  final VoidCallback? onHost;
  final VoidCallback? onClone;
  final VoidCallback? onDownloadImage;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final bool compactStatusBadge;
  final bool showFavorite;
  final bool hideHostInfo;

  static const _coverWidth = 108.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final priceLabel =
        session.priceLabel ??
        (session.feeConfig?.isSplitEvenly ?? false
            ? l10n.sessionRecommendationSplitEvenly
            : null);
    final showActions =
        onHost != null ||
        onClone != null ||
        onDownloadImage != null ||
        onShare != null ||
        onDelete != null;
    final showNewAddress = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cover(
                session: session,
                width: _coverWidth,
                compactStatusBadge: compactStatusBadge,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm + 2,
                    AppSpacing.sm + 2,
                    AppSpacing.sm + 2,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              session.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (showFavorite) ...[
                            const SizedBox(width: AppSpacing.xs),
                            FavoriteButton(
                              key: ValueKey('session-favorite-${session.id}'),
                              type: FavoriteType.session,
                              targetId: session.id,
                              initialIsFavorite: session.isFavorite,
                              variant: FavoriteButtonVariant.surface,
                              showCount: false,
                              size: 24,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (!hideHostInfo && session.displayHostName.isNotEmpty)
                        _HostLine(session: session),
                      if (session.displayStartTime case final start?)
                        _TimeLine(
                          start: start,
                          end: session.plannedEndTime,
                          locale: Localizations.localeOf(
                            context,
                          ).languageCode,
                          todayLabel: l10n.dateToday,
                          tomorrowLabel: l10n.dateTomorrow,
                          yesterdayLabel: l10n.dateYesterday,
                        ),
                      if (session.hasLocation)
                        _MetaLine(
                          icon: AppIcons.location,
                          text: session.displayPlace(
                            showNewAddress: showNewAddress,
                          ),
                          trailing: session.distance == null
                              ? null
                              : '${session.distance!.toStringAsFixed(1)} km',
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: LevelRangeChips(
                                requiredLevels: session.requiredLevels,
                              ),
                            ),
                          ),
                          if (priceLabel != null)
                            Text(
                              priceLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      if (showActions) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
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
                                      horizontal: 14,
                                      vertical: AppSpacing.sm,
                                    ),
                                    minimumSize: const Size(0, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(AppIcons.settings, size: 18),
                                  label: const Text(
                                    'Host',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
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
                                    const Size(40, 40),
                                  ),
                                ),
                                icon: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: palette.border),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  child: const Icon(
                                    AppIcons.moreVert,
                                    size: 20,
                                  ),
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
                                          const Icon(
                                            AppIcons.download,
                                            size: 18,
                                          ),
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
  const _SlotsBadge({required this.session, this.compact = false});

  final Session session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    if (session.status == SessionStatus.finished) {
      return Container(
        key: const Key('session-finished-badge'),
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            AppRadius.sm,
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(
          AppRadius.sm,
        ),
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
  const _Cover({
    required this.session,
    required this.width,
    this.compactStatusBadge = false,
  });

  final Session session;
  final double width;
  final bool compactStatusBadge;

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
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, _) => ColoredBox(color: palette.muted),
              errorWidget: (context, _, _) => _Placeholder(palette: palette),
            ),
          ),
          if (session.isCrawled)
            const Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _CrawledBadge(),
            ),
          if (!session.isCrawled &&
              (session.availableSlots != null ||
                  session.status == SessionStatus.finished))
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _SlotsBadge(
                session: session,
                compact: compactStatusBadge,
              ),
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
  const _CrawledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1877F2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0xFF8BB9FF)),
        boxShadow: const [BoxShadow(color: Color(0x471877F2), blurRadius: 8)],
      ),
      child: Text(
        AppLocalizations.of(context).sessionCrawledBadge,
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
    final image = session.displayHostImage;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          UserAvatar(
            name: session.displayHostName,
            imageUrl: image,
            size: 24,
            borderWidth: 0,
            boxShadow: const [],
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(
              session.displayHostName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              key: const Key('session-host-name'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({
    required this.start,
    required this.end,
    required this.locale,
    required this.todayLabel,
    required this.tomorrowLabel,
    required this.yesterdayLabel,
  });

  final DateTime start;
  final DateTime? end;
  final String locale;
  final String todayLabel;
  final String tomorrowLabel;
  final String yesterdayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const dateColor = Color(0xFFF97316);
    final timeColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
        : const Color(0xFF3F3F46);
    final date = Dates.relativeDay(
      start,
      locale: locale,
      todayLabel: todayLabel,
      tomorrowLabel: tomorrowLabel,
      yesterdayLabel: yesterdayLabel,
    );
    final time = end == null
        ? Dates.timeOnly(start, locale: locale)
        : '${Dates.timeOnly(start, locale: locale)}-'
              '${Dates.timeOnly(end!, locale: locale)}';
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          const Icon(AppIcons.clock, size: 13, color: dateColor),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '$date,',
                    key: const Key('session-date-value'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle?.copyWith(color: dateColor),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    time,
                    key: const Key('session-time-value'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle?.copyWith(color: timeColor),
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final tint = palette.mutedForeground;

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
