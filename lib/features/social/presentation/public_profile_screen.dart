import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/constants/image_constants.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/avatar_url.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/profile/application/profile_controller.dart';
import 'package:vmito_app/features/profile/data/profile_image_picker.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_collapsing_header.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_header_geometry.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_tab_skeletons.dart';
import 'package:vmito_app/features/social/presentation/widgets/public_profile_skeleton.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card.dart';
import 'package:vmito_app/features/social/presentation/widgets/user_achievements_skeleton.dart';
import 'package:vmito_app/features/social/presentation/widgets/user_achievements_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

List<String> publicProfileTabLabels(AppLocalizations l10n) => [
  l10n.profileTabPosts,
  l10n.profileTabAchievements,
  l10n.profileTabHosted,
  l10n.profileTabClubs,
  l10n.profileTabReviews,
];

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({
    required this.userId,
    this.isRootProfile = false,
    super.key,
  });

  final String userId;
  final bool isRootProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(publicProfileProvider(userId));
    return Scaffold(
      body: bundle.when(
        data: (data) => _ProfileTabs(
          userId: userId,
          bundle: data,
          isRootProfile: isRootProfile,
        ),
        loading: () => PublicProfileSkeleton(
          isRootProfile: isRootProfile,
          onMenuTap: () =>
              ref.read(appShellScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(publicProfileProvider(userId)),
        ),
      ),
    );
  }
}

class _ProfileTabs extends ConsumerStatefulWidget {
  const _ProfileTabs({
    required this.userId,
    required this.bundle,
    required this.isRootProfile,
  });

  final String userId;
  final PublicProfileBundle bundle;
  final bool isRootProfile;

  @override
  ConsumerState<_ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends ConsumerState<_ProfileTabs>
    with TickerProviderStateMixin {
  late TabController _controller;
  final _outerScrollController = ScrollController();
  final _scrollOffset = ValueNotifier<double>(0);
  VoidCallback? _removeReselectHandler;
  var _screenWidth = 375.0;
  var _usesCompactSystemOverlay = false;
  var _loadedTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: 5,
      vsync: this,
    );
    _controller.addListener(_loadSelectedTab);
    _outerScrollController.addListener(_handleOuterScroll);
    if (widget.isRootProfile) {
      _removeReselectHandler = ref
          .read(tabReselectionControllerProvider)
          .register(
            tabIndex: 4,
            onReselect: () => scrollToTop(_outerScrollController),
          );
    }
  }

  void _handleOuterScroll() {
    final offset = _outerScrollController.offset;
    _scrollOffset.value = offset;
    final usesCompactOverlay =
        ProfileHeaderGeometry.collapseProgress(offset, _screenWidth) >= .85;
    if (usesCompactOverlay != _usesCompactSystemOverlay && mounted) {
      setState(() => _usesCompactSystemOverlay = usesCompactOverlay);
    }
  }

  bool get _isOwner => ref.read(currentUserProvider)?.id == widget.userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.sizeOf(context).width;
  }

  void _loadSelectedTab() {
    final index = _controller.index;
    if (!_loadedTabs.contains(index)) {
      setState(() => _loadedTabs = {..._loadedTabs, index});
    }
  }

  bool get _supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pickProfileImage({required bool avatar}) async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.image),
              title: Text(l10n.profileChooseGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            if (_supportsCamera)
              ListTile(
                leading: const Icon(AppIcons.camera),
                title: Text(l10n.profileTakePhoto),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    bool success;
    try {
      final image = await ref.read(profileImagePickerProvider)(source);
      if (image == null || !mounted) return;
      success = avatar
          ? await ref
                .read(profileControllerProvider.notifier)
                .uploadAvatar(widget.userId, image)
          : await ref
                .read(profileControllerProvider.notifier)
                .uploadCover(widget.userId, image);
    } on Object {
      success = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          avatar
              ? success
                    ? l10n.profileAvatarUpdated
                    : l10n.profileAvatarUploadFailed
              : success
              ? l10n.profileCoverUpdated
              : l10n.profileCoverUploadFailed,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeReselectHandler?.call();
    _outerScrollController
      ..removeListener(_handleOuterScroll)
      ..dispose();
    _scrollOffset.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = publicProfileTabLabels(l10n);
    final safeAreaTop = MediaQuery.paddingOf(context).top;
    final mutations = ref.watch(profileControllerProvider);
    return Stack(
      children: [
        NestedScrollView(
          controller: _outerScrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            ProfileCollapsingHeader(
              profile: widget.bundle.profile,
              scrollOffset: _scrollOffset,
              isRootProfile: widget.isRootProfile,
              isOwner: _isOwner,
              usesCompactSystemOverlay: _usesCompactSystemOverlay,
              menuTooltip: l10n.menuOpenTooltip,
              shareTooltip: l10n.commonShare,
              settingsTooltip: l10n.settingsTitle,
              changeCoverTooltip: l10n.profileChangeCover,
              onMenuTap: () => ref
                  .read(appShellScaffoldKeyProvider)
                  .currentState
                  ?.openDrawer(),
              onShare: () {
                final box = context.findRenderObject();
                SharePlus.instance.share(
                  ShareParams(
                    text: '${AppConfig.webBaseUrl}/user/${widget.userId}',
                    // iPad anchors the share sheet to the tapped rect;
                    // without it the sheet throws rather than opening.
                    sharePositionOrigin: box is RenderBox
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null,
                  ),
                );
              },
              onSettings: () => context.pushNamed(AppRoutes.nameSettings),
              coverProgress: mutations.coverProgress,
              onChangeCover: _isOwner
                  ? () => _pickProfileImage(avatar: false)
                  : null,
              onViewCover: () => showAppLightbox(
                context,
                images: [
                  widget.bundle.profile.coverPhoto ?? kDefaultCoverPhoto,
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _ProfileHeader(
                profile: widget.bundle.profile,
                bundle: widget.bundle,
                scrollOffset: _scrollOffset,
                onSelectTab: _controller.animateTo,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabBarDelegate(
                child: _ProfileTabBar(
                  controller: _controller,
                  labels: labels,
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _controller,
            children: [
              _lazyTab(
                0,
                () => _PostsTab(userId: widget.userId),
                placeholder: const ProfilePostsSkeleton(),
              ),
              _lazyTab(
                1,
                () => UserAchievementsTab(
                  userId: widget.userId,
                  profile: widget.bundle.profile,
                  isOwner: _isOwner,
                ),
                placeholder: const UserAchievementsSkeleton(),
              ),
              _lazyTab(
                2,
                () => _HostedTab(userId: widget.userId),
                placeholder: const ProfileHostedSkeleton(),
              ),
              _lazyTab(
                3,
                () => _ClubsTab(userId: widget.userId, owner: _isOwner),
                placeholder: const ProfileClubsSkeleton(),
              ),
              // Reviews come with the profile bundle; nothing to wait for.
              _lazyTab(
                4,
                () => _ReviewsTab(bundle: widget.bundle),
                placeholder: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        _OverlayAvatar(
          profile: widget.bundle.profile,
          scrollOffset: _scrollOffset,
          screenWidth: _screenWidth,
          safeAreaTop: safeAreaTop,
          isOwner: _isOwner,
          avatarProgress: mutations.avatarProgress,
          changeAvatarTooltip: AppLocalizations.of(
            context,
          ).profileChangeAvatar,
          onChangeAvatar: () => _pickProfileImage(avatar: true),
          onViewAvatar: widget.bundle.profile.image == null
              ? null
              : () => showAppLightbox(
                  context,
                  images: [fullSizeAvatarUrl(widget.bundle.profile.image!)],
                ),
        ),
      ],
    );
  }

  /// [placeholder] shows while the user drags toward a tab that has not been
  /// selected yet; the tab is only built (and fetches) once it is selected.
  Widget _lazyTab(
    int index,
    Widget Function() builder, {
    required Widget placeholder,
  }) => _loadedTabs.contains(index) ? builder() : placeholder;
}

/// Renders the large avatar in a screen-level overlay, not inside either
/// sliver — a `SliverAppBar` clips its own flexibleSpace, and content from the
/// following sliver paints underneath a pinned one, so 50% overlap onto the
/// cover is only reliable outside both.
class _OverlayAvatar extends StatelessWidget {
  const _OverlayAvatar({
    required this.profile,
    required this.scrollOffset,
    required this.screenWidth,
    required this.safeAreaTop,
    required this.isOwner,
    required this.avatarProgress,
    required this.changeAvatarTooltip,
    required this.onChangeAvatar,
    required this.onViewAvatar,
  });

  final PublicProfile profile;
  final ValueListenable<double> scrollOffset;
  final double screenWidth;
  final double safeAreaTop;
  final bool isOwner;
  final int? avatarProgress;
  final String changeAvatarTooltip;
  final VoidCallback onChangeAvatar;
  final VoidCallback? onViewAvatar;

  static const _radius = 44.0;
  static const _framePadding = 3.0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: scrollOffset,
    builder: (context, offset, _) {
      final opacity = ProfileHeaderGeometry.expandedIdentityOpacity(
        offset,
        screenWidth,
      );
      if (opacity <= 0.01) return const SizedBox.shrink();
      final showEditAction =
          ProfileHeaderGeometry.collapseProgress(offset, screenWidth) < .5;
      final coverBottom =
          safeAreaTop +
          ProfileHeaderGeometry.visibleHeight(offset, screenWidth);
      return Positioned(
        // Align the centre of the complete framed avatar with the cover edge.
        top: coverBottom - _radius - _framePadding,
        left: 0,
        right: 0,
        child: Center(
          child: Opacity(
            key: const ValueKey('profile-expanded-avatar'),
            opacity: opacity,
            child: Transform.scale(
              scale: .85 + (.15 * opacity),
              child: Container(
                key: const ValueKey('profile-avatar-frame'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .16),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(_framePadding),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: avatarProgress == null ? onViewAvatar : null,
                      child: ProfileAvatar(
                        profile: profile,
                        radius: _radius,
                        iconSize: _radius,
                      ),
                    ),
                    if (avatarProgress != null)
                      Positioned.fill(
                        child: DecoratedBox(
                          key: const ValueKey('profile-avatar-upload-progress'),
                          decoration: const BoxDecoration(
                            color: Color(0x99000000),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$avatarProgress%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (isOwner && avatarProgress == null && showEditAction)
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: IconButton(
                          key: const ValueKey(
                            'profile-change-avatar-button',
                          ),
                          tooltip: changeAvatarTooltip,
                          onPressed: onChangeAvatar,
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Material(
                            key: const ValueKey(
                              'profile-change-avatar-visual',
                            ),
                            color: Theme.of(context).colorScheme.primary,
                            elevation: 2,
                            shape: const CircleBorder(
                              side: BorderSide(color: Colors.white, width: 2),
                            ),
                            child: const SizedBox.square(
                              dimension: 30,
                              child: Icon(
                                AppIcons.camera,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.bundle,
    required this.scrollOffset,
    required this.onSelectTab,
  });

  final PublicProfile profile;
  final PublicProfileBundle bundle;
  final ValueListenable<double> scrollOffset;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          const SizedBox(height: 60),
          ValueListenableBuilder<double>(
            valueListenable: scrollOffset,
            builder: (context, offset, _) => Opacity(
              key: const ValueKey('profile-expanded-name'),
              opacity: ProfileHeaderGeometry.expandedIdentityOpacity(
                offset,
                screenWidth,
              ),
              child: EmojiSafeText(
                profile.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          if (profile.createdAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppLocalizations.of(context).profileJoinedOn(
                Dates.dateOnly(
                  profile.createdAt!,
                  locale: Localizations.localeOf(context).languageCode,
                ),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).extension<AppPalette>()!.mutedForeground,
              ),
            ),
          ],
          if (profile.levelDescription != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Chip(label: Text(profile.levelDescription!)),
          ],
          const SizedBox(height: AppSpacing.sm + 4),
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  key: const ValueKey('profile-inline-stats'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InlineStat(
                      value: _compactCount(bundle.hostedSessionsCount),
                      label: AppLocalizations.of(
                        context,
                      ).profileHostedSessionsCount,
                      onTap: () => onSelectTab(2),
                    ),
                    const _StatSeparator(),
                    _InlineStat(
                      value: _compactCount(profile.joinedSessionsCount),
                      label: AppLocalizations.of(
                        context,
                      ).profileJoinedSessionsCount,
                      onTap: () => onSelectTab(2),
                    ),
                    const _StatSeparator(),
                    _InlineStat(
                      value: bundle.stats.total == 0
                          ? '0'
                          : bundle.stats.average.toStringAsFixed(1),
                      label: AppLocalizations.of(context).profileReviewsCount,
                      onTap: () => onSelectTab(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _compactCount(int value) {
  if (value < 1000) return '$value';

  final divisor = value < 1000000 ? 1000 : 1000000;
  final suffix = value < 1000000 ? 'K' : 'M';
  final compact = value / divisor;
  final digits = compact >= 10 || compact == compact.roundToDouble() ? 0 : 1;
  return '${compact.toStringAsFixed(digits)}$suffix';
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface.withValues(alpha: .78);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$value ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: label),
                ],
              ),
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatSeparator extends StatelessWidget {
  const _StatSeparator();

  @override
  Widget build(BuildContext context) => Text(
    '•',
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .78),
      fontWeight: FontWeight.w700,
    ),
  );
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => kTextTabBarHeight;

  @override
  double get maxExtent => kTextTabBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) =>
      child != oldDelegate.child;
}

class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({required this.controller, required this.labels});

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: const ValueKey('profile-tab-bar'),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: .5),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        // The container owns both separators; the indicator should remain
        // the only strong visual accent in the tab bar.
        dividerColor: Colors.transparent,
        tabs: [for (final label in labels) Tab(text: label)],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _PostsTab extends ConsumerStatefulWidget {
  const _PostsTab({required this.userId});
  final String userId;
  @override
  ConsumerState<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends ConsumerState<_PostsTab> {
  var _page = 1;
  var _more = true;
  var _loadingMore = false;
  var _posts = <SocialPost>[];
  late Future<void> _future;
  @override
  void initState() {
    super.initState();
    _future = _refresh();
  }

  Future<void> _refresh() async {
    final result = await ref
        .read(profileTabsServiceProvider)
        .posts(widget.userId);
    _posts = result.posts;
    _page = result.page;
    _more = result.hasMore;
  }

  Future<void> _reload() async {
    final future = _refresh();
    setState(() => _future = future);
    await future;
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 300 &&
        _more &&
        !_loadingMore) {
      unawaited(_loadMore());
    }
    return false;
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final result = await ref
          .read(profileTabsServiceProvider)
          .posts(widget.userId, page: _page + 1);
      final ids = _posts.map((item) => item.id).toSet();
      if (mounted) {
        setState(() {
          _posts.addAll(result.posts.where((item) => ids.add(item.id)));
          _page = result.page;
          _more = result.hasMore;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppErrorView(
          error: snapshot.error!,
          onRetry: () => setState(() => _future = _refresh()),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const ProfilePostsSkeleton();
      }
      return NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            key: PageStorageKey('profile-posts-${widget.userId}'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: _posts.isEmpty
                ? 1
                : _posts.length + (_loadingMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (_posts.isEmpty) {
                return _Empty(AppLocalizations.of(context).profileNoPosts);
              }
              if (index == _posts.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return SocialPostCard(
                post: _posts[index],
                onPostChanged: (updated) {
                  if (!mounted) return;
                  setState(() => _posts[index] = updated);
                },
                onDeletePost: (postId) async {
                  if (!mounted) return;
                  setState(
                    () => _posts.removeWhere((post) => post.id == postId),
                  );
                },
                onReportPost: (postId) async {
                  if (!mounted) return;
                  setState(
                    () => _posts.removeWhere((post) => post.id == postId),
                  );
                },
                onOpen: () =>
                    context.push(AppRoutes.socialPost(_posts[index].id)),
              );
            },
          ),
        ),
      );
    },
  );
}

class _HostedTab extends ConsumerStatefulWidget {
  const _HostedTab({required this.userId});
  final String userId;
  @override
  ConsumerState<_HostedTab> createState() => _HostedTabState();
}

class _HostedTabState extends ConsumerState<_HostedTab> {
  var _filter = 'active';
  late Future<pagination.Page<Session>> _future;
  late Future<Map<String, int>> _countsFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _countsFuture = _loadCounts();
  }

  Future<pagination.Page<Session>> _load([String? filter]) => ref
      .read(profileTabsServiceProvider)
      .hosted(widget.userId, filter: filter ?? _filter);

  Future<Map<String, int>> _loadCounts() async {
    final service = ref.read(profileTabsServiceProvider);
    final pages = await Future.wait(
      _hostedFilters.map(
        (filter) => service.hosted(widget.userId, filter: filter.value),
      ),
    );
    return {
      for (var index = 0; index < _hostedFilters.length; index++)
        _hostedFilters[index].value: pages[index].total,
    };
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FutureBuilder<Map<String, int>>(
        future: _countsFuture,
        builder: (context, snapshot) => _HostedFilterChips(
          selected: _filter,
          counts: snapshot.data ?? const {},
          onSelected: (value) => setState(() {
            _filter = value;
            _future = _load(value);
          }),
        ),
      ),
      Expanded(
        child: FutureBuilder<pagination.Page<Session>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorView(
                error: snapshot.error!,
                onRetry: () => setState(() {
                  _future = _load();
                  _countsFuture = _loadCounts();
                }),
              );
            }
            if (!snapshot.hasData) return const ProfileHostedSkeleton();
            final sessions = snapshot.data!.items;
            if (sessions.isEmpty) {
              return _Empty(
                AppLocalizations.of(context).profileNoHostedSessions,
              );
            }
            return ListView.separated(
              key: PageStorageKey(
                'profile-hosted-${widget.userId}-$_filter',
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return SessionCard(
                  session: session,
                  onTap: () => context.push(
                    AppRoutes.sessionDetail(session.slug ?? session.id),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

const _hostedFilters = [
  _HostedFilter(value: 'active'),
  _HostedFilter(value: 'ended'),
  _HostedFilter(value: 'all'),
];

class _HostedFilter {
  const _HostedFilter({required this.value});

  final String value;
}

class _HostedFilterChips extends StatelessWidget {
  const _HostedFilterChips({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _hostedFilters) ...[
            _HostedFilterChip(
              label: _label(context, filter),
              selected: selected == filter.value,
              onTap: () => onSelected(filter.value),
            ),
            if (filter != _hostedFilters.last) const SizedBox(width: 8),
          ],
        ],
      ),
    ),
  );

  String _label(BuildContext context, _HostedFilter filter) {
    final count = counts[filter.value];
    final l10n = AppLocalizations.of(context);
    final label = switch (filter.value) {
      'active' => l10n.profileHostedFilterActive,
      'ended' => l10n.profileHostedFilterEnded,
      _ => l10n.profileHostedFilterAll,
    };
    return count == null ? label : '$label ($count)';
  }
}

class _HostedFilterChip extends StatelessWidget {
  const _HostedFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark()
            : AppPalette.light());
    final background = selected ? AppColors.brand : theme.colorScheme.surface;
    final foreground = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Material(
      color: background,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.brand : palette.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubsTab extends ConsumerStatefulWidget {
  const _ClubsTab({required this.userId, required this.owner});
  final String userId;
  final bool owner;
  @override
  ConsumerState<_ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends ConsumerState<_ClubsTab> {
  late Future<List<ClubSummary>> _future;
  @override
  void initState() {
    super.initState();
    _future = ref.read(profileTabsServiceProvider).clubs(widget.userId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ClubSummary>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppErrorView(
          error: snapshot.error!,
          onRetry: () => setState(
            () => _future = ref
                .read(profileTabsServiceProvider)
                .clubs(widget.userId),
          ),
        );
      }
      if (!snapshot.hasData) return const ProfileClubsSkeleton();
      final l10n = AppLocalizations.of(context);
      final all = snapshot.data!;
      final hosted = all.where((club) => club.hostId == widget.userId).toList();
      final member = all.where((club) => club.hostId != widget.userId).toList();
      return RefreshIndicator(
        onRefresh: () async => setState(
          () => _future = ref
              .read(profileTabsServiceProvider)
              .clubs(widget.userId),
        ),
        child: ListView(
          key: PageStorageKey('profile-clubs-${widget.userId}'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            if (all.isEmpty) _Empty(l10n.profileNoClubs),
            if (hosted.isNotEmpty || widget.owner)
              _clubGroup(
                context,
                l10n.profileHostedClubs,
                hosted,
                trailing: widget.owner
                    ? TextButton(
                        key: const Key('profile-manage-clubs-button'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                        ),
                        onPressed: () => context.push(AppRoutes.manageClubs),
                        child: Text(l10n.clubManageTitle),
                      )
                    : null,
              ),
            if (widget.owner && member.isNotEmpty)
              _clubGroup(context, l10n.profileJoinedClubs, member),
          ],
        ),
      );
    },
  );
}

Widget _clubGroup(
  BuildContext context,
  String title,
  List<ClubSummary> clubs, {
  Widget? trailing,
}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$title (${clubs.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
          ],
        ),
        if (clubs.isEmpty)
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context).profileNoClubsInGroup,
            ),
          ),
        for (final club in clubs)
          ListTile(
            leading: CircleAvatar(
              backgroundImage: club.logo == null
                  ? null
                  : CachedNetworkImageProvider(club.logo!),
              child: club.logo == null ? const Icon(AppIcons.clubs) : null,
            ),
            title: Text(club.name),
            subtitle: Text(
              AppLocalizations.of(context).socialMemberCount(club.memberCount),
            ),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () =>
                context.push(AppRoutes.clubDetail(club.slug ?? club.id)),
          ),
      ],
    ),
  ),
);

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.bundle});
  final PublicProfileBundle bundle;
  @override
  Widget build(BuildContext context) => ListView(
    key: PageStorageKey('profile-reviews-${bundle.profile.id}'),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.screenPadding),
    children: [
      Card(
        child: ListTile(
          leading: const Icon(AppIcons.star, color: Colors.amber),
          title: Text(
            AppLocalizations.of(context).profileAverageRating(
              bundle.stats.average.toStringAsFixed(1),
            ),
          ),
          subtitle: Text(
            AppLocalizations.of(context).profileRatingsCount(
              bundle.stats.total,
            ),
          ),
        ),
      ),
      if (bundle.ratings.isEmpty)
        _Empty(AppLocalizations.of(context).profileNoReviews)
      else
        for (final rating in bundle.ratings)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: rating.raterImage == null
                    ? null
                    : CachedNetworkImageProvider(rating.raterImage!),
                child: rating.raterImage == null
                    ? const Icon(AppIcons.profile)
                    : null,
              ),
              title: Text(
                rating.raterName ?? AppLocalizations.of(context).appName,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('★' * rating.rating),
                  if (rating.comment?.isNotEmpty ?? false)
                    Text(rating.comment!),
                  Text(
                    Dates.dateOnly(
                      rating.createdAt,
                      locale: Localizations.localeOf(context).languageCode,
                    ),
                  ),
                ],
              ),
            ),
          ),
    ],
  );
}
