import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/club_browse_filters.dart';
import 'package:vmito_app/features/social/domain/post_composer_draft.dart';
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

  Future<bool> refresh() async {
    try {
      final result = await _service.feed(page: 1);
      state = FeedState(
        posts: result.posts,
        page: result.page,
        hasMore: result.hasMore,
      );
      if (ref.read(authControllerProvider).status == AuthStatus.authenticated) {
        unawaited(
          ref.read(newsfeedBadgeControllerProvider.notifier).markAsRead(),
        );
      }
      return true;
    } on Object catch (error) {
      state = state.copyWith(error: error);
      return false;
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

  Future<void> createPost(PostComposerDraft draft) async {
    final post = await _service.createPost(draft);
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
    this.filters = const ClubBrowseFilters(),
    // "Gần tôi nhất" by default, matching the web client. Coordinates are
    // resolved on the browse screen; the backend only distance-sorts once
    // lat/lng are attached.
    this.sortBy = 'distance',
    this.latitude,
    this.longitude,
  });

  final List<ClubSummary> clubs;
  final String search;
  final int page;
  final int totalPages;
  final bool isLoading;
  final Object? error;
  final ClubBrowseFilters filters;
  final String sortBy;
  final double? latitude;
  final double? longitude;

  bool get hasMore => page > 0 && page < totalPages;
  int get activeFilterCount => filters.activeCount;
}

class ClubsController extends Notifier<ClubsState> {
  @override
  ClubsState build() => const ClubsState();

  // Snapshot restoration is an action, not a property mutation API.
  // ignore: use_setters_to_change_properties
  void restore(ClubsState snapshot) => state = snapshot;

  Future<void> load({
    String? search,
    ClubBrowseFilters? filters,
    String? sortBy,
    double? latitude,
    double? longitude,
  }) async {
    final nextSearch = search ?? state.search;
    final nextFilters = filters ?? state.filters;
    final nextSort = sortBy ?? state.sortBy;
    final nextLatitude = latitude ?? state.latitude;
    final nextLongitude = longitude ?? state.longitude;
    state = ClubsState(
      clubs: state.clubs,
      search: nextSearch,
      isLoading: true,
      filters: nextFilters,
      sortBy: nextSort,
      latitude: nextLatitude,
      longitude: nextLongitude,
    );
    try {
      final result = await ref
          .read(socialServiceProvider)
          .browseClubs(
            page: 1,
            search: nextSearch,
            filters: nextFilters,
            sortBy: nextSort,
            latitude: nextLatitude,
            longitude: nextLongitude,
          );
      state = ClubsState(
        clubs: sortClubs(result.clubs, nextSort),
        search: nextSearch,
        page: result.page,
        totalPages: result.totalPages,
        filters: nextFilters,
        sortBy: nextSort,
        latitude: nextLatitude,
        longitude: nextLongitude,
      );
    } on Object catch (error) {
      state = ClubsState(
        search: nextSearch,
        error: error,
        filters: nextFilters,
        sortBy: nextSort,
        latitude: nextLatitude,
        longitude: nextLongitude,
      );
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
      filters: current.filters,
      sortBy: current.sortBy,
      latitude: current.latitude,
      longitude: current.longitude,
    );
    try {
      final result = await ref
          .read(socialServiceProvider)
          .browseClubs(
            page: current.page + 1,
            search: current.search,
            filters: current.filters,
            sortBy: current.sortBy,
            latitude: current.latitude,
            longitude: current.longitude,
          );
      state = ClubsState(
        clubs: sortClubs([...current.clubs, ...result.clubs], current.sortBy),
        search: current.search,
        page: result.page,
        totalPages: result.totalPages,
        filters: current.filters,
        sortBy: current.sortBy,
        latitude: current.latitude,
        longitude: current.longitude,
      );
    } on Object catch (error) {
      state = ClubsState(
        clubs: current.clubs,
        search: current.search,
        page: current.page,
        totalPages: current.totalPages,
        error: error,
        filters: current.filters,
        sortBy: current.sortBy,
        latitude: current.latitude,
        longitude: current.longitude,
      );
    }
  }
}

/// Client-side order for a page of clubs. Public so the Home search preview
/// orders its page exactly as the browse list does.
List<ClubSummary> sortClubs(List<ClubSummary> clubs, String sortBy) {
  final sorted = [...clubs];
  switch (sortBy) {
    case 'distance':
      // Trust the server's nearest-first ordering; re-sorting client-side
      // would only corrupt it when a page omits the computed distance.
      break;
    case 'name':
      sorted.sort(
        (first, second) => first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        ),
      );
    case 'createdAt':
      sorted.sort(
        (first, second) => (second.createdAt ?? DateTime(0)).compareTo(
          first.createdAt ?? DateTime(0),
        ),
      );
    default:
      sorted.sort(
        (first, second) => second.memberCount.compareTo(first.memberCount),
      );
  }
  return sorted;
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
    required this.hostedSessionsCount,
  });

  final PublicProfile profile;
  final RatingStats stats;
  final List<PlayerRating> ratings;
  final int hostedSessionsCount;
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
        final hosted = await ref
            .watch(profileTabsServiceProvider)
            .hosted(userId);
        return PublicProfileBundle(
          profile: profile,
          stats: stats,
          ratings: ratings,
          hostedSessionsCount: hosted.total,
        );
      },
    );

/// Rating summaries for the visible session hosts, fetched in one request.
///
/// The key is a sorted, comma-delimited set of ids. A string key gives
/// the provider stable equality as pagination changes the session list.
// ignore: specify_nonobvious_property_types
final batchRatingStatsProvider =
    FutureProvider.family<Map<String, RatingStats>, String>((
      ref,
      hostIdsKey,
    ) async {
      final hostIds = hostIdsKey
          .split(',')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (hostIds.isEmpty) return const {};
      final stats = await ref
          .watch(socialServiceProvider)
          .batchRatingStats(hostIds);
      return {
        for (final stat in stats)
          if (stat.userId case final userId? when userId.isNotEmpty)
            userId: stat,
      };
    });

// Keep the callable provider family while its implementation type is private.
// ignore: specify_nonobvious_property_types
final ratingEligibilityProvider =
    FutureProvider.family<RatingEligibility, String>((ref, sessionId) {
      return ref.watch(socialServiceProvider).ratingEligibility(sessionId);
    });
