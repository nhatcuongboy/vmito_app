import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/news/domain/article.dart';

class NewsService {
  const NewsService(this._client);
  final ApiClient _client;

  dynamic _payload(dynamic body) =>
      body is Map<String, dynamic> && body.containsKey('success')
      ? body['data']
      : body;

  Future<ArticlePage> browse({
    ArticleCategory? category,
    String? tag,
    String? search,
    required int page,
    int limit = 12,
  }) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.articles,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (category != null) 'category': category.wireValue,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ArticlePage.fromJson(
      _payload(response.data) as Map<String, dynamic>,
    );
  }

  /// Returns `null` on 404, matching the web service's silent-not-found
  /// behavior — a missing slug is a normal outcome, not an error.
  Future<Article?> bySlug(String slug) async {
    try {
      final response = await _client.get<dynamic>(ApiEndpoints.article(slug));
      return Article.fromJson(_payload(response.data) as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Related articles are a nice-to-have on the detail screen; any failure
  /// degrades to an empty rail rather than blocking the article itself.
  Future<List<Article>> related(String slug) async {
    try {
      final response = await _client.get<dynamic>(
        ApiEndpoints.articleRelated(slug),
      );
      final raw = _payload(response.data) as List<dynamic>? ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Article.fromJson)
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<ArticleCategoryCount>> categoryCounts() async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.articleCategories,
    );
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ArticleCategoryCount.fromJson)
        .toList(growable: false);
  }

  /// Fire-and-forget view tracking, matching the web app's mount-time call —
  /// a failed ping should never surface to the reader.
  Future<void> trackView(String slug) async {
    try {
      await _client.post<dynamic>(ApiEndpoints.articleView(slug));
    } on Object {
      // Ignored — view tracking is best-effort.
    }
  }
}

final newsServiceProvider = Provider<NewsService>(
  (ref) => NewsService(ref.watch(apiClientProvider)),
);
