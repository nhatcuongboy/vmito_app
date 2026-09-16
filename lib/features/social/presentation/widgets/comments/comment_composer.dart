import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Pinned comment input: current-user avatar, pill field, send button, and a
/// "Replying to X" strip while a reply prefix is active.
class CommentComposer extends StatelessWidget {
  const CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.userName,
    required this.isSubmitting,
    required this.onSubmit,
    this.userImage,
    this.replyingTo,
    this.onCancelReply,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String userName;
  final String? userImage;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final String? replyingTo;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor ?? scheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingTo case final name?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.socialReplyingTo(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).cancelButtonLabel,
                      onPressed: onCancelReply,
                      icon: const Icon(AppIcons.close),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: PostAvatar(
                      name: userName,
                      imageUrl: userImage,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('comment-field'),
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.socialCommentAsHint(userName),
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSend =
                          value.text.trim().isNotEmpty && !isSubmitting;
                      return IconButton(
                        key: const Key('comment-send'),
                        onPressed: canSend ? onSubmit : null,
                        color: scheme.primary,
                        icon: isSubmitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(AppIcons.send),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
