import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/news/application/news_controller.dart';
import 'package:vmito_app/features/news/domain/article.dart';
import 'package:vmito_app/features/news/presentation/widgets/news_article_card.dart';
import 'package:vmito_app/features/news/presentation/widgets/news_category_chips.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_paginated_list_view.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// The mobile redesign of `vmito-fe`'s `/news` grid: a single-column,
/// infinite-scrolling feed instead of a two-column grid with a "Load more"
/// button — the load-more pattern is a desktop affordance, not a mobile one.
class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen({super.key});

  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final initialTag = GoRouterState.of(context).uri.queryParameters['tag'];
    unawaited(
      ref.read(newsListControllerProvider.notifier).load(tag: initialTag),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 380) {
      unawaited(ref.read(newsListControllerProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(newsListControllerProvider);
    final countsAsync = ref.watch(newsCategoryCountsProvider);
    final counts = <ArticleCategory, int>{
      for (final entry
          in countsAsync.asData?.value ?? const <ArticleCategoryCount>[])
        entry.category: entry.count,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: NewsCategoryChips(
              selected: state.category,
              counts: counts,
              onSelected: (category) => unawaited(
                ref
                    .read(newsListControllerProvider.notifier)
                    .load(category: category),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(newsListControllerProvider.notifier)
                  .load(category: state.category, isPullToRefresh: true),
              child: switch (state) {
                _ when state.isLoading && state.items.isEmpty =>
                  const _NewsListSkeleton(),
                _ when state.error != null && state.items.isEmpty =>
                  _NewsListStatus(
                    child: AppErrorView(
                      error: state.error!,
                      onRetry: () => ref
                          .read(newsListControllerProvider.notifier)
                          .load(category: state.category),
                    ),
                  ),
                _ when state.items.isEmpty => _NewsListStatus(
                  child: Text(l10n.newsEmptyState),
                ),
                _ => AppPaginatedListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  itemCount: state.items.length,
                  hasMore: state.hasMore,
                  isLoading: state.isLoading,
                  isLoadingMore: state.isLoadingMore,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => NewsArticleCard(
                    article: state.items[index],
                    featured:
                        index == 0 &&
                        state.category == null &&
                        state.items[index].isFeatured,
                    onTap: () => context.push(
                      AppRoutes.newsDetail(state.items[index].slug),
                    ),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsListStatus extends StatelessWidget {
  const _NewsListStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}

class _NewsListSkeleton extends StatelessWidget {
  const _NewsListSkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.screenPadding),
    itemCount: 4,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
    itemBuilder: (context, index) => const Card(
      clipBehavior: Clip.antiAlias,
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: AppSkeletonBox(radius: 0)),
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: 90, height: 18),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeletonBox(height: 18),
                  SizedBox(height: AppSpacing.xs),
                  AppSkeletonBox(width: 200, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
