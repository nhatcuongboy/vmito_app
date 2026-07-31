import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';

class FeedState {
  const FeedState({
    this.posts = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<SocialPost> posts;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;

  FeedState copyWith({
    List<SocialPost>? posts,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
  }) => FeedState(
    posts: posts ?? this.posts,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : error ?? this.error,
  );
}

class FeedController extends Notifier<FeedState> {
  @override
  FeedState build() => const FeedState();

  SocialService get _service => ref.read(socialServiceProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.feed(page: 1);
      state = FeedState(
        posts: result.posts,
        page: result.page,
        hasMore: result.hasMore,
      );
    } on Object catch (error) {
      state = FeedState(error: error);
    }
  }

  Future<void> refresh() async {
    try {
      final result = await _service.feed(page: 1);
      state = FeedState(
        posts: result.posts,
        page: result.page,
        hasMore: result.hasMore,
      );
    } on Object catch (error) {
      state = state.copyWith(error: error);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await _service.feed(page: state.page + 1);
      final ids = state.posts.map((post) => post.id).toSet();
      state = FeedState(
        posts: [
          ...state.posts,
          ...result.posts.where((post) => !ids.contains(post.id)),
        ],
        page: result.page,
        hasMore: result.hasMore,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }

  Future<void> createPost(
    String content, {
    List<String> imagePaths = const [],
  }) async {
    final post = await _service.createPost(content, imagePaths: imagePaths);
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  Future<void> toggleLike(String postId) async {
    final index = state.posts.indexWhere((post) => post.id == postId);
    if (index < 0) {
      await _service.toggleLike(postId);
      ref.invalidate(postDetailProvider(postId));
      return;
    }
    final before = state.posts[index];
    _replace(
      postId,
      before.copyWith(
        isLiked: !before.isLiked,
        likeCount: before.likeCount + (before.isLiked ? -1 : 1),
      ),
    );
    try {
      final result = await _service.toggleLike(postId);
      _replace(
        postId,
        before.copyWith(isLiked: result.liked, likeCount: result.count),
      );
      ref.invalidate(postDetailProvider(postId));
    } on Object {
      _replace(postId, before);
      rethrow;
    }
  }

  Future<void> addComment(String postId, String content) async {
    await _service.createComment(postId, content);
    SocialPost? post;
    for (final item in state.posts) {
      if (item.id == postId) {
        post = item;
        break;
      }
    }
    if (post != null) {
      _replace(postId, post.copyWith(commentCount: post.commentCount + 1));
    }
    ref.invalidate(postCommentsProvider(postId));
  }

  Future<void> repost(String postId) async {
    final shared = await _service.repost(postId);
    state = state.copyWith(posts: [shared, ...state.posts]);
  }

  void _replace(String id, SocialPost replacement) {
    state = state.copyWith(
      posts: [
        for (final post in state.posts)
          if (post.id == id) replacement else post,
      ],
    );
  }
}

final feedControllerProvider = NotifierProvider<FeedController, FeedState>(
  FeedController.new,
);

// The callable family type is intentionally inferred; flutter_riverpod does
// not export the concrete FutureProviderFamily implementation type.
// ignore: specify_nonobvious_property_types
final postCommentsProvider = FutureProvider.family<List<SocialComment>, String>(
  (ref, postId) => ref.watch(socialServiceProvider).comments(postId),
);

// Same callable family implementation detail as postCommentsProvider above.
// ignore: specify_nonobvious_property_types
final postDetailProvider = FutureProvider.family<SocialPost, String>(
  (ref, postId) => ref.watch(socialServiceProvider).postById(postId),
);

class ClubsState {
  const ClubsState({
    this.clubs = const [],
    this.search = '',
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.error,
  });

  final List<ClubSummary> clubs;
  final String search;
  final int page;
  final int totalPages;
  final bool isLoading;
  final Object? error;

  bool get hasMore => page > 0 && page < totalPages;
}

class ClubsController extends Notifier<ClubsState> {
  @override
  ClubsState build() => const ClubsState();

  Future<void> load({String search = ''}) async {
    state = ClubsState(
      clubs: state.clubs,
      search: search,
      isLoading: true,
    );
    try {
      final result = await ref
          .read(socialServiceProvider)
          .browseClubs(page: 1, search: search);
      state = ClubsState(
        clubs: result.clubs,
        search: search,
        page: result.page,
        totalPages: result.totalPages,
      );
    } on Object catch (error) {
      state = ClubsState(search: search, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    final current = state;
    state = ClubsState(
      clubs: current.clubs,
      search: current.search,
      page: current.page,
      totalPages: current.totalPages,
      isLoading: true,
    );
    try {
      final result = await ref
          .read(socialServiceProvider)
          .browseClubs(page: current.page + 1, search: current.search);
      state = ClubsState(
        clubs: [...current.clubs, ...result.clubs],
        search: current.search,
        page: result.page,
        totalPages: result.totalPages,
      );
    } on Object catch (error) {
      state = ClubsState(
        clubs: current.clubs,
        search: current.search,
        page: current.page,
        totalPages: current.totalPages,
        error: error,
      );
    }
  }
}

final clubsControllerProvider = NotifierProvider<ClubsController, ClubsState>(
  ClubsController.new,
);

// Keep the callable provider family while its implementation type is private.
// ignore: specify_nonobvious_property_types
final clubDetailProvider = FutureProvider.family<ClubSummary, String>(
  (ref, clubId) => ref.watch(socialServiceProvider).clubById(clubId),
);

class PublicProfileBundle {
  const PublicProfileBundle({
    required this.profile,
    required this.stats,
    required this.ratings,
  });

  final PublicProfile profile;
  final RatingStats stats;
  final List<PlayerRating> ratings;
}

// Keep the callable provider family while its implementation type is private.
// ignore: specify_nonobvious_property_types
final publicUserProvider = FutureProvider.family<PublicProfile, String>(
  (ref, userId) => ref.watch(socialServiceProvider).publicProfile(userId),
);

// Keep the callable provider family while its implementation type is private.
// ignore: specify_nonobvious_property_types
final publicProfileProvider =
    FutureProvider.family<PublicProfileBundle, String>(
      (ref, userId) async {
        final service = ref.watch(socialServiceProvider);
        final profile = await service.publicProfile(userId);
        final stats = await service.ratingStats(userId);
        final ratings = await service.receivedRatings(userId);
        return PublicProfileBundle(
          profile: profile,
          stats: stats,
          ratings: ratings,
        );
      },
    );

// Keep the callable provider family while its implementation type is private.
// ignore: specify_nonobvious_property_types
final ratingEligibilityProvider =
    FutureProvider.family<RatingEligibility, String>((ref, sessionId) {
      return ref.watch(socialServiceProvider).ratingEligibility(sessionId);
    });
