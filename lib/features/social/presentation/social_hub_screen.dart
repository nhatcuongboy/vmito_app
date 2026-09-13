import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/notification_header_button.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/presentation/widgets/feed_skeleton.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_avatar.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_composer_sheet.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen> {
  Future<void> _showComposer() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostComposerSheet(
        userName: ref.read(currentUserProvider)?.name ?? '',
        userImage: ref.read(currentUserProvider)?.image,
        onSubmit: ref.read(feedControllerProvider.notifier).createPost,
      ),
    );
    if (posted == true && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.socialPostCreated)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: Consumer(
          builder: (context, ref, _) => IconButton(
            tooltip: l10n.menuOpenTooltip,
            icon: const Icon(AppIcons.menu),
            onPressed: () => ref
                .read(appShellScaffoldKeyProvider)
                .currentState
                ?.openDrawer(),
          ),
        ),
        title: Text(l10n.socialTitle),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final isAuthenticated =
                  ref.watch(authControllerProvider).status ==
                  AuthStatus.authenticated;
              return isAuthenticated
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('social-create-post'),
                          tooltip: l10n.socialCreatePost,
                          icon: const Icon(AppIcons.add),
                          onPressed: _showComposer,
                        ),
                        const NotificationHeaderButton(),
                      ],
                    )
                  : IconButton(
                      tooltip: l10n.authSignIn,
                      icon: const Icon(AppIcons.login),
                      onPressed: () => context.push(AppRoutes.signIn),
                    );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _FeedTab(onCreatePost: _showComposer),
    );
  }
}

class _FeedTab extends ConsumerStatefulWidget {
  const _FeedTab({required this.onCreatePost});

  final VoidCallback onCreatePost;

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab> {
  final _scrollController = ScrollController();
  late final VoidCallback _removeReselectHandler;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _removeReselectHandler = ref
        .read(tabReselectionControllerProvider)
        .register(
          tabIndex: 2,
          onReselect: () => scrollToTop(_scrollController),
        );
    unawaited(
      Future<void>.microtask(
        () => ref.read(feedControllerProvider.notifier).load(),
      ),
    );
  }

  @override
  void dispose() {
    _removeReselectHandler();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      unawaited(ref.read(feedControllerProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedControllerProvider);
    final user = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context);
    if (state.isLoading && state.posts.isEmpty) {
      return const FeedSkeleton();
    }
    if (state.error != null && state.posts.isEmpty) {
      return AppErrorView(
        error: state.error!,
        onRetry: ref.read(feedControllerProvider.notifier).load,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(feedControllerProvider.notifier).refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _ComposerCard(
                userName: user?.name ?? '',
                userImage: user?.image,
                hint: user?.name != null
                    ? l10n.socialComposerNameHint(user!.name ?? '')
                    : l10n.socialComposerHint,
                onTap: widget.onCreatePost,
              ),
            ),
          ),
          if (state.posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(l10n.socialNoPosts)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                AppSpacing.lg,
              ),
              sliver: SliverList.separated(
                itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  if (index == state.posts.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final post = state.posts[index];
                  return SocialPostCard(
                    post: post,
                    onOpen: () => context.push(AppRoutes.socialPost(post.id)),
                    onDeletePost: (postId) async => ref
                        .read(feedControllerProvider.notifier)
                        .deletePost(postId),
                    onReportPost: (postId) async => ref
                        .read(feedControllerProvider.notifier)
                        .reportPost(postId),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Composer prompt card — matches the web newsfeed composer card.
class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.userName,
    required this.hint,
    required this.onTap,
    this.userImage,
  });

  final String userName;
  final String? userImage;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              PostAvatar(
                name: userName,
                imageUrl: userImage,
                size: 40,
                bordered: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hint,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: palette.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
