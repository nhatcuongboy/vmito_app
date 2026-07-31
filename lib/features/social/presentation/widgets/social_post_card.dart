import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SocialPostCard extends ConsumerWidget {
  SocialPostCard({required this.post, this.onOpen, super.key})
    : _shareCardKey = GlobalKey();

  final SocialPost post;
  final VoidCallback? onOpen;
  final GlobalKey _shareCardKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return RepaintBoundary(
      key: _shareCardKey,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: post.author.image == null
                    ? null
                    : CachedNetworkImageProvider(post.author.image!),
                child: post.author.image == null
                    ? const Icon(Icons.person_outline_rounded)
                    : null,
              ),
              title: Text(post.author.name),
              subtitle: Text(
                Dates.dayAndTime(
                  post.createdAt,
                  locale: Localizations.localeOf(context).languageCode,
                ),
              ),
              onTap: post.author.id.isEmpty
                  ? null
                  : () => context.push(AppRoutes.publicProfile(post.author.id)),
            ),
            if (post.content.trim().isNotEmpty)
              InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Text(post.content, style: theme.textTheme.bodyLarge),
                ),
              ),
            if (post.locationName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(post.locationName!)),
                  ],
                ),
              ),
            if (post.images.isNotEmpty)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: PageView.builder(
                  itemCount: post.images.length,
                  itemBuilder: (context, index) => CachedNetworkImage(
                    imageUrl: post.images[index].url,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            if (post.originalPost case final original?)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          original.author.name,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (original.content.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(original.content),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: Key('like-${post.id}'),
                      onPressed: () => _toggleLike(context, ref),
                      icon: Icon(
                        post.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: post.isLiked ? theme.colorScheme.error : null,
                      ),
                      label: Text('${post.likeCount}'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      key: Key('comments-${post.id}'),
                      onPressed: () => showCommentsSheet(context, post.id),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text('${post.commentCount}'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showShareActions(context, ref),
                      icon: const Icon(Icons.share_outlined),
                      label: Text('${post.shareCount}'),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(label: l10n.socialPostActions, child: const SizedBox()),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleLike(post.id);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _showShareActions(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: Text(l10n.socialRepost),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref.read(feedControllerProvider.notifier).repost(post.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
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
    final boundary = _shareCardKey.currentContext?.findRenderObject();
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
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Text(
                l10n.socialComments,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: comments.when(
                  data: (items) => items.isEmpty
                      ? Center(child: Text(l10n.socialNoComments))
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final comment = items[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: comment.user.image == null
                                    ? null
                                    : CachedNetworkImageProvider(
                                        comment.user.image!,
                                      ),
                                child: comment.user.image == null
                                    ? const Icon(Icons.person_outline_rounded)
                                    : null,
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
                        : const Icon(Icons.send_rounded),
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
