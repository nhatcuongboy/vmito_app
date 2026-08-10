import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_avatar.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SocialHubScreen extends StatefulWidget {
  const SocialHubScreen({super.key});

  @override
  State<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends State<SocialHubScreen> {
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
      ),
      body: const _FeedTab(),
    );
  }
}

class _FeedTab extends ConsumerStatefulWidget {
  const _FeedTab();

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(
      Future<void>.microtask(
        () => ref.read(feedControllerProvider.notifier).load(),
      ),
    );
  }

  @override
  void dispose() {
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
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.posts.isEmpty) {
      return AppErrorView(
        error: state.error!,
        onRetry: ref.read(feedControllerProvider.notifier).load,
      );
    }
    return RefreshIndicator(
      onRefresh: ref.read(feedControllerProvider.notifier).refresh,
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
                onTap: _showComposer,
                onImageTap: _showComposer,
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showComposer() async {
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showDialog<_PostDraft>(
      context: context,
      builder: (_) => const _PostComposerDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(feedControllerProvider.notifier)
          .createPost(draft.content, imagePaths: draft.imagePaths);
    } on Object catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _PostDraft {
  const _PostDraft({required this.content, required this.imagePaths});

  final String content;
  final List<String> imagePaths;
}

/// Composer prompt card — matches the web newsfeed composer card.
class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.userName,
    required this.hint,
    required this.onTap,
    required this.onImageTap,
    this.userImage,
  });

  final String userName;
  final String? userImage;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback onImageTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
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
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Image button
              GestureDetector(
                onTap: onImageTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    AppIcons.imagePlus,
                    size: 20,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostComposerDialog extends StatefulWidget {
  const _PostComposerDialog();

  @override
  State<_PostComposerDialog> createState() => _PostComposerDialogState();
}

class _PostComposerDialogState extends State<_PostComposerDialog> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final _images = <XFile>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.socialCreatePost),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('post-content-field'),
                controller: _controller,
                autofocus: true,
                maxLength: 2000,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(hintText: l10n.socialComposerHint),
                onChanged: (_) => setState(() {}),
              ),
              if (_images.isNotEmpty)
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.file(
                            File(_images[index].path),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => _images.removeAt(index)),
                            icon: const Icon(AppIcons.close, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _images.length >= 10 ? null : _pickImages,
                  icon: const Icon(AppIcons.imagePlus),
                  label: Text(l10n.socialAddPhotos),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty && _images.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _PostDraft(
                    content: _controller.text.trim(),
                    imagePaths: _images.map((image) => image.path).toList(),
                  ),
                ),
          child: Text(l10n.socialPublish),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    final selected = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      limit: 10 - _images.length,
    );
    if (!mounted || selected.isEmpty) return;
    setState(() => _images.addAll(selected));
  }
}


