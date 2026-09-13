import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Renders the body of an ACTIVITY-type post.
///
/// Mirrors `ActivityPostContent.tsx` from the web:
///   1. A text headline generated from the activity type + metadata.
///   2. An entity preview card (session / club / tournament / user).
///
/// Only handles the activity types that the current mobile API exposes.
class ActivityPostContent extends StatelessWidget {
  const ActivityPostContent({required this.post, super.key});

  final SocialPost post;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = post.metadata ?? const {};
    final authorName = post.author.name;
    final activityType = post.activityType ?? '';

    final headlineText = _buildHeadline(activityType, authorName, meta);

    final headline = headlineText != null
        ? _Headline(text: headlineText, isDark: isDark)
        : null;

    return switch (activityType) {
      'SESSION_CREATED' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null) headline,
          _EntityPreviewCard(
            isDark: isDark,
            image: meta['coverPhoto'] as String?,
            title: meta['sessionName'] as String? ?? '',
            subtitle: meta['location'] as String?,
            sportType: _parseSportType(meta['sportType']),
            icon: const Icon(AppIcons.calendar, size: 24, color: Colors.white),
            onTap: () {
              final id = meta['sessionId'] as String?;
              final slug = meta['sessionSlug'] as String?;
              if (id != null) {
                context.push(AppRoutes.sessionDetail(slug ?? id));
              }
            },
          ),
        ],
      ),
      'SESSION_RESULTS' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null) headline,
          _EntityPreviewCard(
            isDark: isDark,
            image: meta['coverPhoto'] as String?,
            title: meta['sessionName'] as String? ?? '',
            subtitle: meta['location'] as String?,
            sportType: _parseSportType(meta['sportType']),
            icon: const Icon(AppIcons.award, size: 24, color: Colors.white),
            onTap: () {
              final id = meta['sessionId'] as String?;
              final slug = meta['sessionSlug'] as String?;
              if (id != null) {
                context.push(AppRoutes.sessionDetail(slug ?? id));
              }
            },
          ),
        ],
      ),
      'TOURNAMENT_CREATED' || 'TOURNAMENT_FINISHED' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null) headline,
          _EntityPreviewCard(
            isDark: isDark,
            image: meta['coverPhoto'] as String?,
            title: meta['tournamentName'] as String? ?? '',
            subtitle: meta['venueName'] as String?,
            sportType: _parseSportType(meta['sportType']),
            icon: const Icon(AppIcons.trophy, size: 24, color: Colors.white),
            onTap: () {
              final id = meta['tournamentId'] as String?;
              final slug = meta['tournamentSlug'] as String?;
              if (id != null) {
                context.push(AppRoutes.tournamentDetail(slug ?? id));
              }
            },
          ),
        ],
      ),
      'CLUB_CREATED' || 'CLUB_UPDATED' || 'CLUB_MEMBER_JOINED' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null) headline,
          _EntityPreviewCard(
            isDark: isDark,
            image: meta['logo'] as String?,
            title: meta['clubName'] as String? ?? '',
            icon: Icon(
              activityType == 'CLUB_MEMBER_JOINED'
                  ? AppIcons.userPlus
                  : AppIcons.users,
              size: 24,
              color: Colors.white,
            ),
            onTap: () {
              final id = meta['clubId'] as String?;
              if (id != null) context.push(AppRoutes.clubDetail(id));
            },
          ),
        ],
      ),
      'AVATAR_UPDATED' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null) headline,
          if (_getAvatarImageUrl(meta, post) case final imgUrl?)
            _FullImage(
              url: imgUrl,
              isDark: isDark,
            ),
        ],
      ),
      'COVER_PHOTO_UPDATED' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null) headline,
          if (_getCoverPhotoUrl(meta, post) case final coverUrl?)
            _FullImage(
              url: coverUrl,
              isDark: isDark,
            ),
        ],
      ),
      'USER_RATED' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null) headline,
          if (meta['ratedUserId'] != null)
            _EntityPreviewCard(
              isDark: isDark,
              image: meta['ratedImage'] as String?,
              title: meta['ratedName'] as String? ?? '',
              icon: const Icon(AppIcons.star, size: 24, color: Colors.white),
              onTap: () {
                final userId = meta['ratedUserId'] as String?;
                if (userId != null) {
                  context.push(AppRoutes.publicProfile(userId));
                }
              },
            ),
        ],
      ),
      _ => headline ?? const SizedBox.shrink(),
    };
  }

  /// Generates a plain-text headline matching the Vietnamese template
  /// strings from the web's `posts.activity.*` i18n keys.
  static String? _buildHeadline(
    String activityType,
    String author,
    Map<String, dynamic> meta,
  ) {
    final club = meta['clubName'] as String? ?? '';
    final session = meta['sessionName'] as String? ?? '';
    final tournament = meta['tournamentName'] as String? ?? '';
    final rated = meta['ratedName'] as String? ?? '';

    return switch (activityType) {
      'SESSION_CREATED' => '$author vừa tạo kèo mới',
      'SESSION_RESULTS' => '$author đã chia sẻ kết quả kèo $session',
      'CLUB_CREATED' => '$author vừa tạo câu lạc bộ $club',
      'CLUB_UPDATED' => '$author đã cập nhật thông tin câu lạc bộ $club',
      'CLUB_MEMBER_JOINED' => '$author đã tham gia câu lạc bộ $club',
      'TOURNAMENT_CREATED' => '$author vừa tạo giải đấu $tournament',
      'TOURNAMENT_FINISHED' => 'Giải đấu $tournament đã kết thúc',
      'AVATAR_UPDATED' => '$author đã cập nhật ảnh đại diện',
      'COVER_PHOTO_UPDATED' => '$author đã cập nhật ảnh bìa',
      'USER_RATED' => '$author đã đánh giá $rated',
      _ => null,
    };
  }

  /// Parses the raw `sportType` metadata string (`BADMINTON`/`PICKLEBALL`)
  /// into the shared session enum, matching the web's `normalizeSportType`.
  static SessionSportType? _parseSportType(Object? value) {
    return switch (value) {
      'BADMINTON' => SessionSportType.badminton,
      'PICKLEBALL' => SessionSportType.pickleball,
      _ => null,
    };
  }

  static String? _getAvatarImageUrl(
    Map<String, dynamic> meta,
    SocialPost post,
  ) {
    final metaUrl =
        meta['image'] ??
        meta['url'] ??
        meta['avatar'] ??
        meta['imageUrl'] ??
        meta['avatarUrl'];
    if (metaUrl is String && metaUrl.isNotEmpty) {
      return metaUrl;
    }
    if (post.images.isNotEmpty && post.images.first.url.isNotEmpty) {
      return post.images.first.url;
    }
    if (post.author.image != null && post.author.image!.isNotEmpty) {
      return post.author.image;
    }
    return null;
  }

  static String? _getCoverPhotoUrl(Map<String, dynamic> meta, SocialPost post) {
    final metaUrl =
        meta['coverPhoto'] ??
        meta['coverPhotoUrl'] ??
        meta['image'] ??
        meta['url'];
    if (metaUrl is String && metaUrl.isNotEmpty) {
      return metaUrl;
    }
    if (post.images.isNotEmpty && post.images.first.url.isNotEmpty) {
      return post.images.first.url;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

/// Gray muted headline text — matches `{author} vừa tạo kèo mới`.
class _Headline extends StatelessWidget {
  const _Headline({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
        ),
      ),
    );
  }
}

/// The green entity preview card matching `EntityPreviewCard` from the web.
///
/// Shows the session/club cover photo (or a green gradient icon fallback),
/// the entity title in green, and an optional subtitle (location, etc).
class _EntityPreviewCard extends StatelessWidget {
  const _EntityPreviewCard({
    required this.isDark,
    required this.title,
    required this.icon,
    required this.onTap,
    this.image,
    this.subtitle,
    this.sportType,
  });

  final bool isDark;
  final String? image;
  final String title;
  final String? subtitle;
  final SessionSportType? sportType;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null && image!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFFE5E7EB).withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover photo OR green gradient icon
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: image!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _GreenIconBox(icon: icon),
                        )
                      : _GreenIconBox(icon: icon),
                ),
              ),
              const SizedBox(width: 14),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                        if (sportType != null) ...[
                          const SizedBox(width: 6),
                          _SportBadge(sportType: sportType!, isDark: isDark),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small round sport-type indicator shown next to an entity preview title.
///
/// Mirrors the web's `AppSportBadge` (`iconOnly` + `soft` variant): a soft
/// tinted circle per sport, distinguishing badminton from pickleball now
/// that both are supported.
class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.sportType, required this.isDark});

  final SessionSportType sportType;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final (emoji, light, dark) = switch (sportType) {
      SessionSportType.badminton => (
        '🏸',
        const Color(0xFFF0FDF4),
        const Color(0xFF052E16),
      ),
      SessionSportType.pickleball => (
        '🏓',
        const Color(0xFFFAF5FF),
        const Color(0xFF3B0764),
      ),
    };
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? dark : light,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 11)),
    );
  }
}

/// Green gradient box shown when no cover image is available.
class _GreenIconBox extends StatelessWidget {
  const _GreenIconBox({required this.icon});

  final Widget icon;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4ADE80), Color(0xFF10B981)],
      ),
    ),
    child: Center(child: icon),
  );
}

/// Full-width image used for avatar/cover photo updates.
class _FullImage extends StatelessWidget {
  const _FullImage({required this.url, required this.isDark});

  final String url;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: GestureDetector(
      key: const Key('activity-post-image'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showAppLightbox(context, images: [url]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 220, maxHeight: 380),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: double.infinity,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}
