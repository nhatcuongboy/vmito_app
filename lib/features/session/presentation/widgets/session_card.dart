import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/level_range_chips.dart';

/// One session in the browse list.
///
/// Horizontal, matching the web's mobile layout: the cover sits on the left so
/// the text column carries the two fields a player actually decides on — the
/// **skill band** and the **price**. A vertical card with a full-width cover
/// pushes both below the fold.
///
/// `BaseSessionCard` on web is 1,482 lines because it serves every context at
/// once. This is the browse card only.
class SessionCard extends StatelessWidget {
  const SessionCard({required this.session, this.onTap, super.key});

  final Session session;
  final VoidCallback? onTap;

  static const _coverWidth = 108.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

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
                          icon: Icons.schedule_rounded,
                          text: time,
                          // Time is the first thing scanned; give it the
                          // accent the rest of the metadata does not have.
                          color: palette.warning,
                        ),
                      if (session.displayPlace.isNotEmpty)
                        _MetaLine(
                          icon: Icons.place_outlined,
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

class _Cover extends StatelessWidget {
  const _Cover({required this.session, required this.width});

  final Session session;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final url = session.coverPhoto;

    return SizedBox(
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, _) => ColoredBox(color: palette.muted),
              errorWidget: (context, _, _) => _Placeholder(palette: palette),
            )
          else
            _Placeholder(palette: palette),
          if (session.isCrawled)
            Positioned(
              top: AppSpacing.xs,
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
        Icons.sports_tennis_rounded,
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
              Icons.person_rounded,
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
