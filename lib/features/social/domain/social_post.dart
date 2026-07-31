class SocialPostAuthor {
  const SocialPostAuthor({required this.id, required this.name, this.image});

  factory SocialPostAuthor.fromJson(Map<String, dynamic> json) =>
      SocialPostAuthor(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Vmito',
        image: json['image'] as String?,
      );

  final String id;
  final String name;
  final String? image;
}

class SocialPostImage {
  const SocialPostImage({required this.id, required this.url, this.order = 0});

  factory SocialPostImage.fromJson(Map<String, dynamic> json) =>
      SocialPostImage(
        id: json['id'] as String? ?? json['publicId'] as String? ?? '',
        url: json['url'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String url;
  final int order;
}

class SocialPost {
  const SocialPost({
    required this.id,
    required this.content,
    required this.author,
    required this.images,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.isLiked,
    required this.createdAt,
    this.originalPost,
    this.locationName,
    this.activityType,
  });

  factory SocialPost.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>? ?? const {};
    final location = json['location'] as Map<String, dynamic>?;
    final rawImages = json['images'] as List<dynamic>? ?? const [];
    final original = json['originalPost'] as Map<String, dynamic>?;
    return SocialPost(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      author: SocialPostAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? const {},
      ),
      images:
          rawImages
              .whereType<Map<String, dynamic>>()
              .map(SocialPostImage.fromJson)
              .toList(growable: false)
            ..sort((a, b) => a.order.compareTo(b.order)),
      likeCount: (count['likes'] as num?)?.toInt() ?? 0,
      commentCount: (count['comments'] as num?)?.toInt() ?? 0,
      shareCount: (count['shares'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      originalPost: original == null ? null : SocialPost.fromJson(original),
      locationName: location?['name'] as String?,
      activityType: json['activityType'] as String?,
    );
  }

  final String id;
  final String content;
  final SocialPostAuthor author;
  final List<SocialPostImage> images;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final DateTime createdAt;
  final SocialPost? originalPost;
  final String? locationName;
  final String? activityType;

  SocialPost copyWith({
    int? likeCount,
    int? commentCount,
    int? shareCount,
    bool? isLiked,
  }) => SocialPost(
    id: id,
    content: content,
    author: author,
    images: images,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    shareCount: shareCount ?? this.shareCount,
    isLiked: isLiked ?? this.isLiked,
    createdAt: createdAt,
    originalPost: originalPost,
    locationName: locationName,
    activityType: activityType,
  );
}

class SocialComment {
  const SocialComment({
    required this.id,
    required this.user,
    required this.content,
    required this.createdAt,
  });

  factory SocialComment.fromJson(Map<String, dynamic> json) => SocialComment(
    id: json['id'] as String? ?? '',
    user: SocialPostAuthor.fromJson(
      json['user'] as Map<String, dynamic>? ?? const {},
    ),
    content: json['content'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String id;
  final SocialPostAuthor user;
  final String content;
  final DateTime createdAt;
}

class SocialPostPage {
  const SocialPostPage({
    required this.posts,
    required this.page,
    required this.hasMore,
  });

  factory SocialPostPage.fromJson(Map<String, dynamic> json) {
    final raw = json['posts'] as List<dynamic>? ?? const [];
    return SocialPostPage(
      posts: raw
          .whereType<Map<String, dynamic>>()
          .map(SocialPost.fromJson)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  final List<SocialPost> posts;
  final int page;
  final bool hasMore;
}
