import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/widgets/comments/post_comments_sheet.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_actions.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

/// Full-screen photos of a post with the author, caption and actions pinned
/// below, so a viewer can like or open comments without leaving the photo.
///
/// [images] defaults to the post's own photos; activity posts (avatar or cover
/// updates) carry their photo in metadata instead and pass it explicitly.
Future<void> showPostImageViewer(
  BuildContext context, {
  required SocialPost post,
  List<String>? images,
  int initialIndex = 0,
  ValueChanged<SocialPost>? onPostChanged,
}) => showAppLightbox(
  context,
  images:
      images ?? post.images.map((image) => image.url).toList(growable: false),
  initialIndex: initialIndex,
  footerBuilder: (_) =>
      PostImageViewerFooter(post: post, onPostChanged: onPostChanged),
);

class PostImageViewerFooter extends ConsumerStatefulWidget {
  const PostImageViewerFooter({
    required this.post,
    this.onPostChanged,
    super.key,
  });

  final SocialPost post;
  final ValueChanged<SocialPost>? onPostChanged;

  @override
  ConsumerState<PostImageViewerFooter> createState() =>
      _PostImageViewerFooterState();
}

class _PostImageViewerFooterState extends ConsumerState<PostImageViewerFooter> {
  // Local copy for posts outside the feed (profile tabs); feed posts are read
  // live from the controller instead.
  late SocialPost _local = widget.post;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final post = ref.watch(feedPostProvider(widget.post.id)) ?? _local;
    const muted = Color(0xFFD1D5DB);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xCC000000), Color(0xF2000000)],
          stops: [0, 0.35, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => openProfileFromOverlay(context, post.author.id),
                child: Text(
                  post.author.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '${Dates.timeAgo(post.createdAt, locale: locale)} · ',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  const Icon(AppIcons.language, size: 12, color: muted),
                ],
              ),
              if (post.content.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _ExpandableCaption(text: post.content.trim()),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _ViewerAction(
                    key: const Key('viewer-like'),
                    icon: post.isLiked
                        ? AppIcons.favoriteFilled
                        : AppIcons.favorite,
                    color: post.isLiked ? const Color(0xFFF43F5E) : null,
                    count: post.likeCount,
                    tooltip: l10n.socialLikeAction,
                    onTap: () => _toggleLike(post),
                  ),
                  _ViewerAction(
                    key: const Key('viewer-comments'),
                    icon: AppIcons.chat,
                    count: post.commentCount,
                    tooltip: l10n.socialCommentAction,
                    onTap: () => showCommentsSheet(
                      context,
                      postId: post.id,
                      post: post,
                    ),
                  ),
                  _ViewerAction(
                    icon: AppIcons.share,
                    count: post.shareCount,
                    tooltip: l10n.socialShareAction,
                    onTap: () => _share(post),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(SocialPost post) => togglePostLike(
    context,
    ref,
    post,
    onPostChanged: (updated) {
      if (mounted) setState(() => _local = updated);
      widget.onPostChanged?.call(updated);
    },
  );

  Future<void> _share(SocialPost post) async {
    final box = context.findRenderObject();
    await SharePlus.instance.share(
      ShareParams(
        text: 'https://vmito.com/newsfeed/${post.id}',
        sharePositionOrigin: box is RenderBox
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onTap,
    this.color,
    super.key,
  });

  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 20, 10),
          child: Row(
            children: [
              Icon(icon, size: 24, color: color ?? Colors.white),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-line caption with an inline "See more"; expanded it scrolls within
/// 40% of the screen so it never covers the whole photo.
class _ExpandableCaption extends StatefulWidget {
  const _ExpandableCaption({required this.text});

  final String text;

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _expanded = false;

  static const _style = TextStyle(
    color: Colors.white,
    fontSize: 15,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final toggleStyle = _style.copyWith(
      color: const Color(0xFFD1D5DB),
      fontWeight: FontWeight.w600,
    );

    if (_expanded) {
      return GestureDetector(
        onTap: () => setState(() => _expanded = false),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          child: SingleChildScrollView(
            child: Text.rich(
              TextSpan(
                style: _style,
                children: [
                  TextSpan(text: '${widget.text} '),
                  TextSpan(text: l10n.socialSeeLess, style: toggleStyle),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        final caption = Text(
          widget.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _style,
        );
        if (!overflows) return caption;
        return GestureDetector(
          onTap: () => setState(() => _expanded = true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              caption,
              Text(l10n.socialSeeMore, style: toggleStyle),
            ],
          ),
        );
      },
    );
  }
}
