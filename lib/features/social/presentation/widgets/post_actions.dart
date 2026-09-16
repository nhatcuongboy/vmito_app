import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';

/// Optimistic like toggle shared by the post card and the image viewer.
///
/// [onPostChanged] lets owners whose posts are local state (profile tabs)
/// mirror the change; feed posts are patched by [FeedController] itself.
Future<void> togglePostLike(
  BuildContext context,
  WidgetRef ref,
  SocialPost post, {
  ValueChanged<SocialPost>? onPostChanged,
}) async {
  final updated = post.copyWith(
    isLiked: !post.isLiked,
    likeCount: post.likeCount + (post.isLiked ? -1 : 1),
  );
  onPostChanged?.call(updated);
  try {
    await ref.read(feedControllerProvider.notifier).toggleLike(post.id);
  } on Object catch (error) {
    onPostChanged?.call(post);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

/// Opens a public profile from an overlay (image viewer, comments sheet).
///
/// Profiles are GoRouter pages while those overlays are imperative routes on
/// the root navigator; pop the overlays first or the profile opens hidden
/// underneath them.
void openProfileFromOverlay(BuildContext context, String userId) {
  if (userId.isEmpty) return;
  final router = GoRouter.of(context);
  Navigator.of(
    context,
    rootNavigator: true,
  ).popUntil((route) => route.settings is Page<Object?>);
  unawaited(router.push(AppRoutes.publicProfile(userId)));
}
