import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/news/application/news_controller.dart';
import 'package:vmito_app/features/news/data/news_service.dart';
import 'package:vmito_app/features/news/domain/article.dart';
import 'package:vmito_app/features/news/presentation/widgets/news_article_card.dart';
import 'package:vmito_app/features/news/presentation/widgets/news_category_label.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget, matching the web app's mount-time view tracking — it
    // fires regardless of whether the article payload has loaded yet.
    unawaited(ref.read(newsServiceProvider).trackView(widget.slug));
  }

  @override
  Widget build(BuildContext context) {
    final articleAsync = ref.watch(newsArticleProvider(widget.slug));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (articleAsync.asData?.value != null)
            IconButton(
              icon: const Icon(AppIcons.share),
              onPressed: () => _share(articleAsync.asData!.value!),
            ),
        ],
      ),
      body: articleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(newsArticleProvider(widget.slug)),
        ),
        data: (article) => article == null
            ? Center(child: Text(l10n.newsEmptyState))
            : _ArticleBody(article: article),
      ),
    );
  }

  void _share(Article article) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final language = localeCode == 'zh' ? 'cn' : localeCode;
    final url = 'https://vmito.com/$language/news/${article.slug}';
    unawaited(
      SharePlus.instance.share(
        ShareParams(title: article.title, text: '${article.title}\n$url'),
      ),
    );
  }
}

class _ArticleBody extends ConsumerWidget {
  const _ArticleBody({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final relatedAsync = ref.watch(newsRelatedArticlesProvider(article.slug));
    final relatedArticles = relatedAsync.asData?.value ?? const <Article>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.coverImage?.isNotEmpty ?? false)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: article.coverImage!,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  newsCategoryLabel(l10n, article.category).toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  article.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MetaRow(article: article, l10n: l10n, localeCode: localeCode),
                const SizedBox(height: AppSpacing.md),
                if (article.content?.isNotEmpty ?? false)
                  HtmlWidget(
                    article.content!,
                    onTapUrl: _launchUrl,
                    textStyle: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                    ),
                  ),
                if (article.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.newsTags, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tag in article.tags)
                        ActionChip(
                          label: Text(tag),
                          onPressed: () => context.push(
                            Uri(
                              path: AppRoutes.news,
                              queryParameters: {'tag': tag},
                            ).toString(),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (relatedArticles.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.newsRelatedArticles,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                itemCount: relatedArticles.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final related = relatedArticles[index];
                  return SizedBox(
                    width: 220,
                    child: NewsArticleCard(
                      article: related,
                      compact: true,
                      onTap: () => context.pushReplacement(
                        AppRoutes.newsDetail(related.slug),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else
            const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<bool> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final author = article.author;
    final publishedAt = article.publishedAt;

    return Row(
      children: [
        if (author != null) ...[
          CircleAvatar(
            radius: 14,
            foregroundImage: (author.image?.isNotEmpty ?? false)
                ? NetworkImage(author.image!)
                : null,
            child: Text(
              author.name.isNotEmpty ? author.name[0].toUpperCase() : '?',
              style: theme.textTheme.labelSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Text(
            [
              if (author != null) author.name,
              if (publishedAt != null)
                Dates.dateOnly(publishedAt, locale: localeCode),
              l10n.newsReadingTime(article.readingTimeMinutes),
              l10n.newsViews(article.viewCount),
            ].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}
