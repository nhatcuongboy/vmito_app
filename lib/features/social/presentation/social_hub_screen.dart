import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.socialTitle),
          actions: [
            IconButton(
              tooltip: l10n.clubManageTitle,
              onPressed: () => context.push(AppRoutes.manageClubs),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.socialFeedTab),
              Tab(text: l10n.socialClubsTab),
            ],
          ),
        ),
        body: const TabBarView(children: [_FeedTab(), _ClubsTab()]),
      ),
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
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user?.image == null
                        ? null
                        : CachedNetworkImageProvider(user!.image!),
                    child: user?.image == null
                        ? const Icon(Icons.person_outline_rounded)
                        : null,
                  ),
                  title: Text(l10n.socialComposerHint),
                  trailing: const Icon(Icons.add_photo_alternate_outlined),
                  onTap: _showComposer,
                ),
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
                0,
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
                            icon: const Icon(Icons.close_rounded, size: 18),
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
                  icon: const Icon(Icons.add_photo_alternate_outlined),
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

class _ClubsTab extends ConsumerStatefulWidget {
  const _ClubsTab();

  @override
  ConsumerState<_ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends ConsumerState<_ClubsTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(clubsControllerProvider.notifier).load(),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubsControllerProvider);
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(clubsControllerProvider.notifier).load(search: state.search),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: state.clubs.length + 2,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return SearchBar(
              controller: _searchController,
              hintText: l10n.socialClubSearch,
              leading: const Icon(Icons.search_rounded),
              onChanged: _search,
            );
          }
          if (index == state.clubs.length + 1) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null && state.clubs.isEmpty) {
              return AppErrorView(
                error: state.error!,
                onRetry: () => ref
                    .read(clubsControllerProvider.notifier)
                    .load(search: state.search),
              );
            }
            if (state.clubs.isEmpty) {
              return Center(child: Text(l10n.socialNoClubs));
            }
            if (state.hasMore) {
              return OutlinedButton(
                onPressed: ref.read(clubsControllerProvider.notifier).loadMore,
                child: Text(l10n.commonLoadMore),
              );
            }
            return const SizedBox.shrink();
          }
          return _ClubCard(club: state.clubs[index - 1]);
        },
      ),
    );
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(clubsControllerProvider.notifier).load(search: value),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club});

  final ClubSummary club;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.socialClub(club.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (club.heroImage != null)
              CachedNetworkImage(
                imageUrl: club.heroImage!,
                height: 150,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox(height: 80),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.socialMemberCount(club.memberCount),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (club.location != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      club.location!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
