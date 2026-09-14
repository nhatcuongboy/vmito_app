import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/widgets/activity_post_content.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

class SocialPostCard extends ConsumerWidget {
  SocialPostCard({
    required this.post,
    this.onOpen,
    this.onPostChanged,
    this.onDeletePost,
    this.onReportPost,
    this.onBlockUser,
    super.key,
  }) : _shareCardKey = GlobalKey();

  final SocialPost post;
  final VoidCallback? onOpen;

  /// Notifies an owner of an optimistic like update (e.g. a profile tab whose
  /// posts are local state rather than part of [feedControllerProvider]).
  final ValueChanged<SocialPost>? onPostChanged;
  final Future<void> Function(String postId)? onDeletePost;
  final Future<void> Function(String postId)? onReportPost;
  final Future<void> Function(String userId)? onBlockUser;
  final GlobalKey _shareCardKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActivity = post.activityType != null;
    final hasEngagement =
        post.likeCount > 0 || post.commentCount > 0 || post.shareCount > 0;

    return RepaintBoundary(
      key: _shareCardKey,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Shared-post banner ─────────────────────────────────────────
            if (post.originalPost != null)
              _SharedBanner(authorName: post.author.name, isDark: isDark),

            // ── Header ─────────────────────────────────────────────────────
            _PostHeader(
              post: post,
              isDark: isDark,
              ref: ref,
              shareCardKey: _shareCardKey,
              onDeletePost: onDeletePost,
              onReportPost: onReportPost,
              onBlockUser: onBlockUser,
            ),

            // ── Activity headline / body ────────────────────────────────────
            if (isActivity) ActivityPostContent(post: post),

            // ── Regular text content ────────────────────────────────────────
            if (!isActivity && post.content.trim().isNotEmpty)
              _PostContent(
                content: post.content,
                onTap: onOpen,
                isDark: isDark,
              ),

            // ── Location badge ──────────────────────────────────────────────
            if (!isActivity && post.locationName != null)
              _LocationBadge(name: post.locationName!, isDark: isDark),

            // ── Image grid ─────────────────────────────────────────────────
            if (!isActivity && post.images.isNotEmpty)
              _ImageGrid(images: post.images),

            // ── Original (shared) post ──────────────────────────────────────
            if (post.originalPost case final original?)
              _OriginalPostCard(post: original, isDark: isDark),

            // ── Engagement counts ───────────────────────────────────────────
            if (hasEngagement)
              _EngagementRow(post: post, isDark: isDark, l10n: l10n),

            // ── Divider ─────────────────────────────────────────────────────
            const Divider(height: 1),

            // ── Action bar ──────────────────────────────────────────────────
            _ActionBar(
              post: post,
              isDark: isDark,
              l10n: l10n,
              ref: ref,
              shareCardKey: _shareCardKey,
              onPostChanged: onPostChanged,
            ),

            // Accessibility label
            Semantics(
              label: l10n.socialPostActions,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal sub-widgets
// ---------------------------------------------------------------------------

class _SharedBanner extends StatelessWidget {
  const _SharedBanner({required this.authorName, required this.isDark});

  final String authorName;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
      child: Row(
        children: [
          const Icon(
            AppIcons.share,
            size: 14,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Post header: avatar + author name + timestamp + globe + optional menu.
class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.isDark,
    required this.ref,
    required this.shareCardKey,
    this.onDeletePost,
    this.onReportPost,
    this.onBlockUser,
  });

  final SocialPost post;
  final bool isDark;
  final WidgetRef ref;
  final GlobalKey shareCardKey;
  final Future<void> Function(String postId)? onDeletePost;
  final Future<void> Function(String postId)? onReportPost;
  final Future<void> Function(String userId)? onBlockUser;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isOwner = currentUserId != null && currentUserId == post.author.id;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: post.author.id.isEmpty
                ? null
                : () => context.push(AppRoutes.publicProfile(post.author.id)),
            child: PostAvatar(
              name: post.author.name,
              imageUrl: post.author.image,
              size: 40,
              bordered: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: post.author.id.isEmpty
                      ? null
                      : () => context.push(
                          AppRoutes.publicProfile(post.author.id),
                        ),
                  child: Text(
                    post.author.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: isDark
                          ? const Color(0xFFF9FAFB)
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      Dates.timeAgo(post.createdAt, locale: locale),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      AppIcons.language,
                      size: 12,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (currentUserId != null && currentUserId.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: l10n.menuOpenTooltip,
              padding: EdgeInsets.zero,
              icon: Icon(
                AppIcons.moreHorizontal,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
              ),
              onSelected: (value) async {
                switch (value) {
                  case 'delete':
                    final confirmed = await showAppConfirmDialog(
                      context,
                      title: l10n.commonDelete,
                      content: l10n.socialDeletePostConfirm,
                      confirmLabel: l10n.commonDelete,
                      type: AppConfirmDialogType.destructive,
                    );
                    if (confirmed != true) return;
                    if (onDeletePost == null) return;
                    try {
                      await onDeletePost!(post.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.socialDeleteSuccess)),
                      );
                    } on Object catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  case 'report':
                    final confirmed = await showAppConfirmDialog(
                      context,
                      title: l10n.socialReportPost,
                      content: l10n.socialReportPostConfirm,
                      confirmLabel: l10n.socialReportPost,
                    );
                    if (confirmed != true) return;
                    if (onReportPost == null) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.socialReportSent)),
                      );
                      return;
                    }
                    try {
                      await onReportPost!(post.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.socialReportSent)),
                      );
                    } on Object catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  case 'block':
                    final confirmed = await showAppConfirmDialog(
                      context,
                      title: l10n.socialBlockUser,
                      content: l10n.socialBlockUserConfirm,
                      confirmLabel: l10n.socialBlockUser,
                    );
                    if (confirmed != true) return;
                    if (post.author.id.isEmpty) return;
                    if (onBlockUser == null) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.socialUserBlocked)),
                      );
                      return;
                    }
                    try {
                      await onBlockUser!(post.author.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.socialUserBlocked)),
                      );
                    } on Object catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];
                if (isOwner) {
                  items.add(
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(AppIcons.delete, size: 18),
                          const SizedBox(width: 12),
                          Text(l10n.commonDelete),
                        ],
                      ),
                    ),
                  );
                } else {
                  items.add(
                    PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          const Icon(AppIcons.warning, size: 18),
                          const SizedBox(width: 12),
                          Text(l10n.socialReportPost),
                        ],
                      ),
                    ),
                  );
                  if (post.author.id.isNotEmpty) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            const Icon(AppIcons.userMinus, size: 18),
                            const SizedBox(width: 12),
                            Text(l10n.socialBlockUser),
                          ],
                        ),
                      ),
                    );
                  }
                }
                return items;
              },
            ),
        ],
      ),
    );
  }
}

/// Regular post text.
class _PostContent extends StatelessWidget {
  const _PostContent({
    required this.content,
    required this.isDark,
    this.onTap,
  });

  final String content;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Text(
          content,
          style: TextStyle(
            fontSize: 17,
            height: 1.6,
            color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}

/// Location chip — matches the web's red pill badge.
class _LocationBadge extends StatelessWidget {
  const _LocationBadge({required this.name, required this.isDark});

  final String name;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF450A0A).withValues(alpha: 0.4)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF7F1D1D).withValues(alpha: 0.5)
                  : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.location,
                size: 13,
                color: isDark
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFB91C1C),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFB91C1C),
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

/// Image grid — 1 image full width, 2+ images in a 2-column grid.
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  final List<SocialPostImage> images;

  @override
  Widget build(BuildContext context) {
    final isSingle = images.length == 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: isSingle
          ? _SingleImage(images: images)
          : _MultiImageGrid(images: images),
    );
  }
}

class _SingleImage extends StatelessWidget {
  const _SingleImage({required this.images});

  final List<SocialPostImage> images;

  @override
  Widget build(BuildContext context) {
    final imageUrls = images.map((image) => image.url).toList(growable: false);
    return GestureDetector(
      key: const Key('post-image-single'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(showAppLightbox(context, images: imageUrls)),
      child: CachedNetworkImage(
        imageUrl: images.first.url,
        height: 320,
        width: double.infinity,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const _ImgError(),
      ),
    );
  }
}

class _MultiImageGrid extends StatelessWidget {
  const _MultiImageGrid({required this.images});
  final List<SocialPostImage> images;
  @override
  Widget build(BuildContext context) {
    final imageUrls = images.map((image) => image.url).toList(growable: false);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: images.length > 4 ? 4 : images.length,
      itemBuilder: (_, index) {
        final isLast = index == 3 && images.length > 4;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(
            showAppLightbox(
              context,
              images: imageUrls,
              initialIndex: index,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: images[index].url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const _ImgError(),
              ),
              if (isLast)
                ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      '+${images.length - 4}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ImgError extends StatelessWidget {
  const _ImgError();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFE5E7EB),
    child: Center(child: Icon(AppIcons.imageOff, color: Color(0xFF9CA3AF))),
  );
}

/// Nested card for the shared/original post.
class _OriginalPostCard extends StatelessWidget {
  const _OriginalPostCard({required this.post, required this.isDark});

  final SocialPost post;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original author + timestamp
            Row(
              children: [
                PostAvatar(
                  name: post.author.name,
                  imageUrl: post.author.image,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFF9FAFB)
                              : const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        Dates.timeAgo(post.createdAt, locale: locale),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                post.content,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: isDark
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF374151),
                ),
              ),
            ],
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  key: Key('shared-post-image-${post.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(
                    showAppLightbox(
                      context,
                      images: post.images
                          .map((image) => image.url)
                          .toList(growable: false),
                    ),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: post.images.first.url,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const _ImgError(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Engagement counts row (likes heart icon + count; comments · shares).
class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.post,
    required this.isDark,
    required this.l10n,
  });

  final SocialPost post;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          // Likes
          if (post.likeCount > 0) ...[
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF43F5E), Color(0xFFEF4444)],
                ),
              ),
              child: const Icon(
                AppIcons.favoriteFilled,
                size: 10,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${post.likeCount}',
              style: TextStyle(fontSize: 14, color: mutedColor),
            ),
          ],
          const Spacer(),
          // Comments
          if (post.commentCount > 0) ...[
            GestureDetector(
              onTap: () => showCommentsSheet(context, post.id),
              child: Text(
                '${post.commentCount} ${l10n.socialCommentAction}',
                style: TextStyle(
                  fontSize: 14,
                  color: mutedColor,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
          if (post.commentCount > 0 && post.shareCount > 0) ...[
            const SizedBox(width: 6),
            Text('·', style: TextStyle(color: mutedColor)),
            const SizedBox(width: 6),
          ],
          if (post.shareCount > 0)
            Text(
              '${post.shareCount} ${l10n.socialShareAction}',
              style: TextStyle(fontSize: 14, color: mutedColor),
            ),
        ],
      ),
    );
  }
}

/// 3-button action bar: Like · Comment · Share.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.post,
    required this.isDark,
    required this.l10n,
    required this.ref,
    required this.shareCardKey,
    this.onPostChanged,
  });

  final SocialPost post;
  final bool isDark;
  final AppLocalizations l10n;
  final WidgetRef ref;
  final GlobalKey shareCardKey;
  final ValueChanged<SocialPost>? onPostChanged;

  @override
  Widget build(BuildContext context) {
    final likeActive = post.isLiked;
    final mutedTextColor = isDark
        ? const Color(0xFFD1D5DB)
        : const Color(0xFF4B5563);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          // ── Like ────────────────────────────────────────────────────────
          Expanded(
            child: _ActionButton(
              key: Key('like-${post.id}'),
              onPressed: () => _toggleLike(context),
              isDark: isDark,
              activeColor: const Color(0xFFDC2626),
              hoverColor: const Color(0xFFFFF1F2),
              hoverColorDark: const Color(0xFF450A0A),
              isActive: likeActive,
              icon: likeActive
                  ? _LikedIcon()
                  : Icon(AppIcons.favorite, size: 18, color: mutedTextColor),
              label: Text(
                likeActive ? l10n.socialLikedAction : l10n.socialLikeAction,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: likeActive ? const Color(0xFFDC2626) : mutedTextColor,
                ),
              ),
            ),
          ),
          // ── Comment ──────────────────────────────────────────────────────
          Expanded(
            child: _ActionButton(
              key: Key('comments-${post.id}'),
              onPressed: () => showCommentsSheet(context, post.id),
              isDark: isDark,
              activeColor: const Color(0xFF16A34A),
              hoverColor: const Color(0xFFF0FDF4),
              hoverColorDark: const Color(0xFF052E16),
              isActive: false,
              icon: Icon(AppIcons.chat, size: 18, color: mutedTextColor),
              label: Text(
                l10n.socialCommentAction,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: mutedTextColor,
                ),
              ),
            ),
          ),
          // ── Share ─────────────────────────────────────────────────────────
          Expanded(
            child: _ActionButton(
              onPressed: () => _showShareActions(context),
              isDark: isDark,
              activeColor: const Color(0xFF2563EB),
              hoverColor: const Color(0xFFEFF6FF),
              hoverColorDark: const Color(0xFF1E3A5F),
              isActive: false,
              icon: Icon(AppIcons.share, size: 18, color: mutedTextColor),
              label: Text(
                l10n.socialShareAction,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: mutedTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(BuildContext context) async {
    final updated = post.copyWith(
      isLiked: !post.isLiked,
      likeCount: post.likeCount + (post.isLiked ? -1 : 1),
    );
    onPostChanged?.call(updated);
    try {
      await ref.read(feedControllerProvider.notifier).toggleLike(post.id);
    } on Object catch (error) {
      onPostChanged?.call(post);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _showShareActions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.repeat),
              title: Text(l10n.socialRepost),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref.read(feedControllerProvider.notifier).repost(post.id);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.share),
              title: Text(l10n.socialShareOutside),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _shareCard(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCard(BuildContext context) async {
    final link = 'https://vmito.com/newsfeed/${post.id}';
    final boundary = shareCardKey.currentContext?.findRenderObject();
    final renderBox = context.findRenderObject();
    final origin = renderBox is RenderBox
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;
    if (boundary is! RenderRepaintBoundary) {
      await SharePlus.instance.share(
        ShareParams(
          text: '${post.content}\n$link',
          sharePositionOrigin: origin,
        ),
      );
      return;
    }
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      await SharePlus.instance.share(
        ShareParams(
          text: '${post.content}\n$link',
          sharePositionOrigin: origin,
        ),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            data.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'vmito-post-${post.id}.png',
          ),
        ],
        text: link,
        sharePositionOrigin: origin,
      ),
    );
  }
}

/// Reusable action button for the action bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.isDark,
    required this.activeColor,
    required this.hoverColor,
    required this.hoverColorDark,
    required this.isActive,
    required this.icon,
    required this.label,
    super.key,
  });

  final VoidCallback onPressed;
  final bool isDark;
  final Color activeColor;
  final Color hoverColor;
  final Color hoverColorDark;
  final bool isActive;
  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: (isDark ? hoverColorDark : hoverColor).withValues(
          alpha: 0.5,
        ),
        highlightColor: (isDark ? hoverColorDark : hoverColor).withValues(
          alpha: 0.3,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 6),
              label,
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled red-gradient circle with a heart icon — the "liked" state.
class _LikedIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF43F5E), Color(0xFFEF4444)],
      ),
    ),
    child: const Icon(AppIcons.favoriteFilled, size: 12, color: Colors.white),
  );
}

// ---------------------------------------------------------------------------
// Comments sheet (unchanged from original)
// ---------------------------------------------------------------------------

Future<void> showCommentsSheet(BuildContext context, String postId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CommentsSheet(postId: postId),
    );

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId});

  final String postId;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final comments = ref.watch(postCommentsProvider(widget.postId));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Text(
                l10n.socialComments,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: comments.when(
                  data: (items) => items.isEmpty
                      ? Center(child: Text(l10n.socialNoComments))
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final comment = items[index];
                            return ListTile(
                              leading: PostAvatar(
                                name: comment.user.name,
                                imageUrl: comment.user.image,
                                size: 36,
                              ),
                              title: Text(comment.user.name),
                              subtitle: Text(comment.content),
                            );
                          },
                        ),
                  error: (error, _) => Center(child: Text(error.toString())),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('comment-field'),
                      controller: _controller,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: l10n.socialCommentHint,
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(feedControllerProvider.notifier)
          .addComment(widget.postId, content);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
