import 'package:flutter/material.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// One comment: avatar, name · time, body, then Reply / Delete.
///
/// There is no like/dislike here on purpose — the backend has no comment
/// reactions — and replies are flat `@Name` mentions, as on the web.
class CommentTile extends StatelessWidget {
  const CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onReply,
    required this.onDelete,
    required this.onOpenProfile,
    this.canReply = true,
    this.mentionNames = const {},
    super.key,
  });

  final SocialComment comment;
  final bool canDelete;
  final bool canReply;

  /// Names that may appear as a leading `@Name` mention. Names contain spaces,
  /// so the mention boundary cannot be parsed from the text alone.
  final Set<String> mentionNames;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final muted = theme.colorScheme.onSurfaceVariant;
    final user = comment.user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpenProfile,
            child: PostAvatar(name: user.name, imageUrl: user.image, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onOpenProfile,
                        child: Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      ' · ${Dates.timeAgo(comment.createdAt, locale: locale)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _CommentBody(
                  content: comment.content,
                  mentionNames: mentionNames,
                ),
                Row(
                  children: [
                    if (canReply)
                      _TextAction(label: l10n.socialReply, onTap: onReply),
                    if (canDelete)
                      _TextAction(label: l10n.commonDelete, onTap: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Highlights a leading `@Name` mention the way the reply button writes it.
class _CommentBody extends StatelessWidget {
  const _CommentBody({required this.content, required this.mentionNames});

  final String content;
  final Set<String> mentionNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(height: 1.4);
    final mention = content.startsWith('@')
        ? mentionNames
              .map((name) => '@$name')
              .where(content.startsWith)
              .fold<String?>(
                null,
                (longest, m) =>
                    longest == null || m.length > longest.length ? m : longest,
              )
        : null;
    if (mention == null) return Text(content, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: mention,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: content.substring(mention.length)),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 20, 6),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like a [CommentTile].
class CommentTileSkeleton extends StatelessWidget {
  const CommentTileSkeleton({this.lineWidth = 220, super.key});

  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeletonBox(width: 40, height: 40, radius: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeletonBox(width: 120, height: 14),
              const SizedBox(height: 8),
              AppSkeletonBox(width: lineWidth, height: 14),
              const SizedBox(height: 10),
              const AppSkeletonBox(width: 48, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}
