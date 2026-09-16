import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/post_comments_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/widgets/comments/comment_composer.dart';
import 'package:vmito_app/features/social/presentation/widgets/comments/comment_tile.dart';
import 'package:vmito_app/features/social/presentation/widgets/comments/comments_sheet_header.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_actions.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Opens the comments of [postId] in a draggable sheet.
///
/// Pushed on the root navigator so it also stacks above the full-screen image
/// viewer; closing it returns to whatever was underneath, photo included.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String postId,
  SocialPost? post,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  useSafeArea: true,
  clipBehavior: Clip.antiAlias,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => PostCommentsSheet(postId: postId, post: post),
);

class PostCommentsSheet extends ConsumerStatefulWidget {
  const PostCommentsSheet({required this.postId, this.post, super.key});

  final String postId;
  final SocialPost? post;

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _replyName;
  bool _isSubmitting = false;

  PostCommentsController get _notifier =>
      ref.read(postCommentsControllerProvider(widget.postId).notifier);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(postCommentsControllerProvider(widget.postId));
    final user = ref.watch(currentUserProvider);
    final post = ref.watch(feedPostProvider(widget.postId)) ?? widget.post;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        snap: true,
        builder: (context, scrollController) => Column(
          children: [
            CommentsSheetHeader(
              commentCount: state.isLoading && post != null
                  ? post.commentCount
                  : state.total,
              likeCount: post?.likeCount,
              shareCount: post?.shareCount,
            ),
            Expanded(
              child: _buildBody(
                context,
                l10n,
                state,
                scrollController,
                canComment: user != null,
              ),
            ),
            if (user != null)
              CommentComposer(
                controller: _controller,
                focusNode: _focusNode,
                userName: user.name ?? user.email,
                userImage: user.image,
                isSubmitting: _isSubmitting,
                onSubmit: _submit,
                replyingTo: _replyName,
                onCancelReply: _cancelReply,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    PostCommentsState state,
    ScrollController scrollController, {
    required bool canComment,
  }) {
    final theme = Theme.of(context);
    if (state.isLoading && state.items.isEmpty) {
      return AppShimmer(
        child: ListView(
          controller: scrollController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            CommentTileSkeleton(),
            CommentTileSkeleton(lineWidth: 160),
            CommentTileSkeleton(lineWidth: 240),
            CommentTileSkeleton(lineWidth: 120),
          ],
        ),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return _CenteredScroll(
        controller: scrollController,
        children: [
          Text(l10n.socialCommentLoadError, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _notifier.load,
            child: Text(l10n.commonRetry),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return _CenteredScroll(
        controller: scrollController,
        children: [
          Icon(AppIcons.chat, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            l10n.socialNoComments,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.socialNoCommentsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final currentUserId = ref.read(currentUserProvider)?.id;
    final names = {for (final comment in state.items) comment.user.name.trim()};
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 400) {
          unawaited(_notifier.loadMore());
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return state.isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }
          final comment = state.items[index];
          return CommentTile(
            key: ValueKey(comment.id),
            comment: comment,
            mentionNames: names,
            canReply: canComment,
            canDelete:
                currentUserId != null && currentUserId == comment.user.id,
            onReply: () => _reply(comment),
            onDelete: () => _delete(comment),
            onOpenProfile: () =>
                openProfileFromOverlay(context, comment.user.id),
          );
        },
      ),
    );
  }

  void _onTextChanged() {
    final name = _replyName;
    if (name == null) return;
    if (!_controller.text.startsWith('@$name ')) {
      setState(() => _replyName = null);
    }
  }

  // Same behaviour as the web CommentSection: swap any previous mention
  // prefix for the new one and keep what the user already typed.
  void _reply(SocialComment comment) {
    final name = comment.user.name.trim();
    final previous = _replyName == null ? null : '@$_replyName ';
    final text = _controller.text;
    final body = previous != null && text.startsWith(previous)
        ? text.substring(previous.length)
        : text;
    final next = '@$name ${body.trimLeft()}';
    _replyName = name;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() {});
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    final name = _replyName;
    if (name == null) return;
    final prefix = '@$name ';
    final text = _controller.text;
    _replyName = null;
    if (text.startsWith(prefix)) {
      _controller.text = text.substring(prefix.length);
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _notifier.add(content);
      _replyName = null;
      _controller.clear();
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete(SocialComment comment) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.socialDeleteComment,
      content: l10n.socialDeleteCommentConfirm,
      confirmLabel: l10n.commonDelete,
      type: AppConfirmDialogType.destructive,
    );
    if (confirmed != true) return;
    try {
      await _notifier.delete(comment.id);
    } on Object catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

/// Centers [children] while keeping the sheet's scroll controller attached, so
/// the empty and error states can still be dragged down to dismiss.
class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.controller, required this.children});

  final ScrollController controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      controller: controller,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    ),
  );
}
