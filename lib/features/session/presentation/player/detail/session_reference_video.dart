import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/reference_video.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The host's reference clip.
///
/// Opens in the browser or the YouTube app rather than playing inline: an
/// embedded player would mean a webview dependency for a link most sessions
/// do not set.
class SessionReferenceVideo extends StatelessWidget {
  const SessionReferenceVideo({required this.video, super.key});

  final ReferenceVideo video;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sessionReferenceVideoTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: palette.muted,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: InkWell(
            onTap: () => unawaited(
              launchUrl(
                Uri.parse(video.url),
                mode: LaunchMode.externalApplication,
              ),
            ),
            child: switch (video) {
              YouTubeVideo(:final thumbnailUrl) => _Thumbnail(
                imageUrl: thumbnailUrl,
              ),
              _ => _LinkRow(url: video.url),
            },
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) => AspectRatio(
    // YouTube serves hqdefault as 4:3 with letterbox bars; cropping to 16:9
    // hides them and matches the web embed.
    aspectRatio: 16 / 9,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          errorWidget: (context, _, _) => const SizedBox.shrink(),
        ),
        const ColoredBox(color: Color(0x33000000)),
        const Center(
          child: Icon(
            AppIcons.playCircle,
            size: 56,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            AppIcons.playCircle,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Icon(
            AppIcons.externalLink,
            size: 18,
            color: palette.mutedForeground,
          ),
        ],
      ),
    );
  }
}
