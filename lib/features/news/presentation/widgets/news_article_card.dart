import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/news/domain/article.dart';
import 'package:vmito_app/features/news/presentation/widgets/news_category_label.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A single article, single-column. [featured] renders a taller cover for
/// the lead item on an unfiltered first page, matching the web app's lead
/// card without needing its two-column grid.
class NewsArticleCard extends StatelessWidget {
  const NewsArticleCard({
    required this.article,
    this.featured = false,
    this.compact = false,
    this.onTap,
    super.key,
  });

  final Article article;
  final bool featured;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: featured ? 16 / 10 : 16 / 9,
              child: _Cover(coverImage: article.coverImage),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBadge(category: article.category),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    article.title,
                    maxLines: compact ? 2 : (featured ? 3 : 2),
                    overflow: TextOverflow.ellipsis,
                    style:
                        (compact
                                ? theme.textTheme.titleSmall
                                : theme.textTheme.titleMedium)
                            ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (!compact && (article.excerpt?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      article.excerpt!,
                      maxLines: featured ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _MetaRow(
                    article: article,
                    l10n: l10n,
                    localeCode: localeCode,
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

class _Cover extends StatelessWidget {
  const _Cover({required this.coverImage});

  final String? coverImage;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final url = coverImage?.trim().isNotEmpty ?? false
        ? coverImage!
        : Session.defaultCoverPhoto;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => ColoredBox(color: palette.muted),
      errorWidget: (context, url, error) => ColoredBox(
        color: palette.muted,
        child: Center(
          child: Icon(AppIcons.news, size: 32, color: palette.mutedForeground),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final ArticleCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        newsCategoryLabel(AppLocalizations.of(context), category),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.article,
    required this.l10n,
    required this.localeCode,
  });

  final Article article;
  final AppLocalizations l10n;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: palette.mutedForeground,
    );
    final publishedAt = article.publishedAt;
    final parts = <String>[
      if (publishedAt != null) Dates.dateOnly(publishedAt, locale: localeCode),
      l10n.newsReadingTime(article.readingTimeMinutes),
      l10n.newsViews(article.viewCount),
    ];
    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
