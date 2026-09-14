import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:vmito_app/features/news/data/news_service.dart';
import 'package:vmito_app/features/news/domain/article.dart';

class NewsListState {
  const NewsListState({
    this.items = const [],
    this.category,
    this.tag,
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isRefetching = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<Article> items;
  final ArticleCategory? category;
  final String? tag;
  final int page;
  final int totalPages;
  final bool isLoading;

  /// True while a filter change is refetching a list that already has items
  /// on screen — distinct from [isLoading], which only covers the first
  /// fetch (nothing rendered yet).
  final bool isRefetching;
  final bool isLoadingMore;
  final Object? error;
  bool get hasMore => page > 0 && page < totalPages;
}

class NewsListController extends Notifier<NewsListState> {
  @override
  NewsListState build() => const NewsListState();

  /// [category] and [tag] are the full new filter, including `null` to mean
  /// "cleared" — callers always pass the current selection, not a partial
  /// update, so there is no ambiguity between "unset" and "not provided".
  Future<void> load({
    ArticleCategory? category,
    String? tag,
    bool isPullToRefresh = false,
  }) async {
    final hasExisting = state.items.isNotEmpty;
    state = NewsListState(
      items: state.items,
      category: category,
      tag: tag,
      isLoading: !hasExisting,
      isRefetching: !isPullToRefresh && hasExisting,
    );
    try {
      final result = await ref
          .read(newsServiceProvider)
          .browse(category: category, tag: tag, page: 1);
      state = NewsListState(
        items: result.items,
        category: category,
        tag: tag,
        page: result.page,
        totalPages: result.totalPages,
      );
    } on Object catch (error) {
      state = NewsListState(category: category, tag: tag, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final before = state;
    state = NewsListState(
      items: before.items,
      category: before.category,
      tag: before.tag,
      page: before.page,
      totalPages: before.totalPages,
      isLoadingMore: true,
    );
    try {
      final result = await ref
          .read(newsServiceProvider)
          .browse(
            category: before.category,
            tag: before.tag,
            page: before.page + 1,
          );
      final ids = before.items.map((article) => article.id).toSet();
      state = NewsListState(
        items: [
          ...before.items,
          ...result.items.where((article) => ids.add(article.id)),
        ],
        category: before.category,
        tag: before.tag,
        page: result.page,
        totalPages: result.totalPages,
      );
    } on Object catch (error) {
      state = NewsListState(
        items: before.items,
        category: before.category,
        tag: before.tag,
        page: before.page,
        totalPages: before.totalPages,
        error: error,
      );
    }
  }
}

final newsListControllerProvider =
    NotifierProvider<NewsListController, NewsListState>(
      NewsListController.new,
    );

final newsCategoryCountsProvider = FutureProvider<List<ArticleCategoryCount>>(
  (ref) => ref.watch(newsServiceProvider).categoryCounts(),
);

final FutureProviderFamily<Article?, String> newsArticleProvider =
    FutureProvider.family<Article?, String>(
      (ref, slug) => ref.watch(newsServiceProvider).bySlug(slug),
    );

final FutureProviderFamily<List<Article>, String> newsRelatedArticlesProvider =
    FutureProvider.family<List<Article>, String>(
      (ref, slug) => ref.watch(newsServiceProvider).related(slug),
    );
