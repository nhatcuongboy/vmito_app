// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';

class PostCommentsState {
  const PostCommentsState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
  });

  final List<SocialComment> items;
  final int total;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;

  PostCommentsState copyWith({
    List<SocialComment>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
  }) => PostCommentsState(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : error ?? this.error,
  );
}

/// Comments of one post, newest first (the backend's order).
///
/// Mirrors the web `CommentSection`: page 1 on open, append on scroll, prepend
/// on create. The feed card's count is patched from [PostCommentsState.total]
/// so both surfaces agree without a feed refetch.
class PostCommentsController extends Notifier<PostCommentsState> {
  PostCommentsController(this.postId);

  final String postId;

  SocialService get _service => ref.read(socialServiceProvider);

  @override
  PostCommentsState build() {
    unawaited(Future.microtask(load));
    return const PostCommentsState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.comments(postId);
      if (!ref.mounted) return;
      state = PostCommentsState(
        items: result.comments,
        total: result.total,
        page: result.page,
        hasMore: result.hasMore,
        isLoading: false,
      );
      _syncCount(mutated: false);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _service.comments(
        postId,
        page: state.page + 1,
      );
      if (!ref.mounted) return;
      // New comments shift offsets between pages; drop duplicates.
      final ids = state.items.map((comment) => comment.id).toSet();
      state = state.copyWith(
        items: [
          ...state.items,
          ...result.comments.where((comment) => !ids.contains(comment.id)),
        ],
        total: result.total,
        page: result.page,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> add(String content) async {
    final comment = await _service.createComment(postId, content);
    if (!ref.mounted) return;
    if (state.items.any((item) => item.id == comment.id)) return;
    state = state.copyWith(
      items: [comment, ...state.items],
      total: state.total + 1,
    );
    _syncCount();
  }

  Future<void> delete(String commentId) async {
    await _service.deleteComment(commentId);
    if (!ref.mounted) return;
    final before = state.items.length;
    final items = state.items.where((item) => item.id != commentId).toList();
    state = state.copyWith(
      items: items,
      total: state.total - (before - items.length),
    );
    _syncCount();
  }

  void _syncCount({bool mutated = true}) {
    ref
        .read(feedControllerProvider.notifier)
        .setCommentCount(postId, state.total);
    if (mutated) ref.invalidate(postDetailProvider(postId));
  }
}

final postCommentsControllerProvider = NotifierProvider.autoDispose
    .family<PostCommentsController, PostCommentsState, String>(
      PostCommentsController.new,
    );
