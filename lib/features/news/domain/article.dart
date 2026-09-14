import 'package:freezed_annotation/freezed_annotation.dart';

part 'article.freezed.dart';
part 'article.g.dart';

/// Mirrors `EArticleCategory` in `vmito-fe/src/types/news.ts`.
@JsonEnum(alwaysCreate: true)
enum ArticleCategory {
  @JsonValue('NEWS')
  news,
  @JsonValue('TUTORIAL')
  tutorial,
  @JsonValue('TOURNAMENT')
  tournament,
  @JsonValue('EQUIPMENT')
  equipment,
  @JsonValue('COMMUNITY')
  community,
}

/// Mirrors `EArticleStatus` in `vmito-fe/src/types/news.ts`. The public API
/// only ever returns `published`, but the field is still parsed since it is
/// present on every payload.
@JsonEnum(alwaysCreate: true)
enum ArticleStatus {
  @JsonValue('DRAFT')
  draft,
  @JsonValue('PUBLISHED')
  published,
  @JsonValue('ARCHIVED')
  archived,
}

@freezed
abstract class ArticleAuthor with _$ArticleAuthor {
  const factory ArticleAuthor({
    required String id,
    required String name,
    String? image,
  }) = _ArticleAuthor;

  factory ArticleAuthor.fromJson(Map<String, dynamic> json) =>
      _$ArticleAuthorFromJson(json);
}

/// One article. Covers both the list payload (`IArticleSummary`, no
/// [content]) and the detail payload (`IArticle`, [content] populated) — the
/// web app splits these into two TS interfaces, but on the client they only
/// ever differ by whether `content` was fetched.
@freezed
abstract class Article with _$Article {
  const factory Article({
    required String id,
    required String slug,
    required String locale,
    required String title,
    String? excerpt,
    String? content,
    String? coverImage,
    required ArticleCategory category,
    @Default(<String>[]) List<String> tags,
    required ArticleStatus status,
    @Default(false) bool isFeatured,
    @Default(0) int readingTimeMinutes,
    @Default(0) int viewCount,
    DateTime? publishedAt,
    DateTime? updatedAt,
    ArticleAuthor? author,
  }) = _Article;

  factory Article.fromJson(Map<String, dynamic> json) =>
      _$ArticleFromJson(json);
}

/// Pagination envelope for `GET /articles` — flat `{items, page, totalPages,
/// total}`, unlike venue's nested `{data, pagination}` shape. Hand-written
/// like `VenuePage`: a page wrapper isn't a domain model worth freezed's
/// generics overhead.
class ArticlePage {
  const ArticlePage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory ArticlePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return ArticlePage(
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(Article.fromJson)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? raw.length,
    );
  }

  final List<Article> items;
  final int page;
  final int totalPages;
  final int total;
}

class ArticleCategoryCount {
  const ArticleCategoryCount({required this.category, required this.count});

  factory ArticleCategoryCount.fromJson(Map<String, dynamic> json) =>
      ArticleCategoryCount(
        category:
            articleCategoryFromWire(json['category'] as String?) ??
            ArticleCategory.news,
        count: (json['count'] as num?)?.toInt() ?? 0,
      );

  final ArticleCategory category;
  final int count;
}

/// Public accessors for the wire values json_serializable generates into the
/// private `_$ArticleCategoryEnumMap` — needed outside this library for query
/// parameters (`NewsService.browse`) and for [ArticleCategoryCount.fromJson].
extension ArticleCategoryWire on ArticleCategory {
  String get wireValue => _$ArticleCategoryEnumMap[this]!;
}

ArticleCategory? articleCategoryFromWire(String? wireValue) {
  if (wireValue == null) return null;
  for (final entry in _$ArticleCategoryEnumMap.entries) {
    if (entry.value == wireValue) return entry.key;
  }
  return null;
}
