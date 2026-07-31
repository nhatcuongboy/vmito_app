import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postDetailProvider(postId));
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).socialPostDetail),
      ),
      body: post.when(
        data: (value) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            SocialPostCard(post: value),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => showCommentsSheet(context, postId),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text(AppLocalizations.of(context).socialComments),
            ),
          ],
        ),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(postDetailProvider(postId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
