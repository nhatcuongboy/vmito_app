import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Drag handle, engagement summary (likes · comments pill · shares) and the
/// sort label. Likes and shares are omitted when the caller has no post.
class CommentsSheetHeader extends StatelessWidget {
  const CommentsSheetHeader({
    required this.commentCount,
    this.likeCount,
    this.shareCount,
    super.key,
  });

  final int commentCount;
  final int? likeCount;
  final int? shareCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final countStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              if (likeCount case final likes? when likes > 0) ...[
                Container(
                  width: 20,
                  height: 20,
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
                    size: 11,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text('$likes', style: countStyle),
                const SizedBox(width: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.socialCommentsCount(commentCount),
                  style: countStyle?.copyWith(color: scheme.primary),
                ),
              ),
              if (shareCount case final shares? when shares > 0) ...[
                const SizedBox(width: 12),
                Text(l10n.socialSharesCount(shares), style: countStyle),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            l10n.socialCommentsNewest,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
