import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_collapsing_header.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_header_geometry.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _publicTabs = [
  'Bài viết',
  'Thành tích',
  'Kèo đã host',
  'Nhóm',
  'Đánh giá',
];
List<String> publicProfileTabLabels({required bool isOwner}) => [
  ..._publicTabs,
  if (isOwner) 'Yêu thích',
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
  late bool _owner;
  final _outerScrollController = ScrollController();
  final _scrollOffset = ValueNotifier<double>(0);
  var _screenWidth = 375.0;
  var _usesCompactSystemOverlay = false;
  var _loadedTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    _owner = _isOwner;
    _controller = TabController(
      length: publicProfileTabLabels(isOwner: _owner).length,
      vsync: this,
    );
    _controller.addListener(_loadSelectedTab);
    _outerScrollController.addListener(_handleOuterScroll);
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

  @override
  void didUpdateWidget(covariant _ProfileTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final owner = _isOwner;
    if (owner != _owner) {
      final oldIndex = _controller.index;
      _controller.dispose();
      _owner = owner;
      _controller = TabController(
        length: publicProfileTabLabels(isOwner: _owner).length,
        vsync: this,
        initialIndex: oldIndex.clamp(
          0,
          publicProfileTabLabels(isOwner: _owner).length - 1,
        ),
      );
      _loadedTabs = _loadedTabs
          .where((index) => index < _controller.length)
          .toSet();
      _controller.addListener(_loadSelectedTab);
    }
  }

  void _loadSelectedTab() {
    final index = _controller.index;
    if (!_loadedTabs.contains(index)) {
      setState(() => _loadedTabs = {..._loadedTabs, index});
    }
  }

  @override
  void dispose() {
    _outerScrollController
      ..removeListener(_handleOuterScroll)
      ..dispose();
    _scrollOffset.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = publicProfileTabLabels(isOwner: _owner);
    final safeAreaTop = MediaQuery.paddingOf(context).top;
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
              isOwner: _owner,
              usesCompactSystemOverlay: _usesCompactSystemOverlay,
              menuTooltip: AppLocalizations.of(context).menuOpenTooltip,
              shareTooltip: AppLocalizations.of(context).commonShare,
              settingsTooltip: AppLocalizations.of(context).settingsTitle,
              onMenuTap: () => ref
                  .read(appShellScaffoldKeyProvider)
                  .currentState
                  ?.openDrawer(),
              onShare: () => SharePlus.instance.share(
                ShareParams(
                  text: '${AppConfig.webBaseUrl}/user/${widget.userId}',
                ),
              ),
              onSettings: () => context.pushNamed(AppRoutes.nameSettings),
            ),
            SliverToBoxAdapter(
              child: _ProfileHeader(
                profile: widget.bundle.profile,
                bundle: widget.bundle,
                scrollOffset: _scrollOffset,
                isOwner: _owner,
                onEdit: () => context.pushNamed(AppRoutes.nameSettings),
                onSelectTab: _controller.animateTo,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabBarDelegate(
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: TabBar(
                    controller: _controller,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [for (final label in labels) Tab(text: label)],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _controller,
            children: [
              _lazyTab(0, () => _PostsTab(userId: widget.userId)),
              _lazyTab(1, () => _AchievementsTab(userId: widget.userId)),
              _lazyTab(2, () => _HostedTab(userId: widget.userId)),
              _lazyTab(
                3,
                () => _ClubsTab(userId: widget.userId, owner: _owner),
              ),
              _lazyTab(4, () => _ReviewsTab(bundle: widget.bundle)),
              if (_owner)
                _lazyTab(5, () => _FavoritesTab(userId: widget.userId)),
            ],
          ),
        ),
        _OverlayAvatar(
          profile: widget.bundle.profile,
          scrollOffset: _scrollOffset,
          screenWidth: _screenWidth,
          safeAreaTop: safeAreaTop,
        ),
      ],
    );
  }

  Widget _lazyTab(int index, Widget Function() builder) =>
      _loadedTabs.contains(index)
      ? builder()
      : const Center(child: CircularProgressIndicator());
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
  });

  final PublicProfile profile;
  final ValueListenable<double> scrollOffset;
  final double screenWidth;
  final double safeAreaTop;

  static const _radius = 44.0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: scrollOffset,
    builder: (context, offset, _) {
      final opacity = ProfileHeaderGeometry.expandedIdentityOpacity(
        offset,
        screenWidth,
      );
      if (opacity == 0) return const SizedBox.shrink();
      final coverBottom =
          safeAreaTop +
          ProfileHeaderGeometry.visibleHeight(offset, screenWidth);
      return Positioned(
        top: coverBottom - _radius,
        left: 0,
        right: 0,
        child: Center(
          child: Opacity(
            key: const ValueKey('profile-expanded-avatar'),
            opacity: opacity,
            child: Transform.scale(
              scale: .85 + (.15 * opacity),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 4,
                  ),
                ),
                child: ProfileAvatar(
                  profile: profile,
                  radius: _radius,
                  iconSize: _radius,
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
    required this.isOwner,
    required this.onEdit,
    required this.onSelectTab,
  });

  final PublicProfile profile;
  final PublicProfileBundle bundle;
  final ValueListenable<double> scrollOffset;
  final bool isOwner;
  final VoidCallback onEdit;
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
          SizedBox(
            height: 56,
            child: isOwner
                ? Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: SizedBox(
                        width: 92,
                        child: OutlinedButton.icon(
                          key: const ValueKey('profile-edit-button'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, AppSizes.minTapTarget),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            textStyle: Theme.of(context).textTheme.labelMedium,
                          ),
                          onPressed: onEdit,
                          icon: const Icon(AppIcons.edit, size: 14),
                          label: Text(
                            AppLocalizations.of(context).profileEditAction,
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          ValueListenableBuilder<double>(
            valueListenable: scrollOffset,
            builder: (context, offset, _) => Opacity(
              key: const ValueKey('profile-expanded-name'),
              opacity: ProfileHeaderGeometry.expandedIdentityOpacity(
                offset,
                screenWidth,
              ),
              child: Text(
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
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '${bundle.hostedSessionsCount}',
                  label: 'Kèo đã host',
                  onTap: () => onSelectTab(2),
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${profile.joinedSessionsCount}',
                  label: 'Kèo tham gia',
                  onTap: () => onSelectTab(2),
                ),
              ),
              Expanded(
                child: _Stat(
                  value: bundle.stats.average.toStringAsFixed(1),
                  label: 'Đánh giá',
                  onTap: () => onSelectTab(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.onTap});

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: SizedBox(
      height: AppSizes.minTapTarget + AppSpacing.md,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
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
        return const Center(child: CircularProgressIndicator());
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
              if (_posts.isEmpty) return const _Empty('Chưa có bài viết.');
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

class _AchievementsTab extends ConsumerStatefulWidget {
  const _AchievementsTab({required this.userId});
  final String userId;
  @override
  ConsumerState<_AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends ConsumerState<_AchievementsTab> {
  late Future<UserAchievements> _future;
  @override
  void initState() {
    super.initState();
    _future = ref.read(profileTabsServiceProvider).achievements(widget.userId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserAchievements>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppErrorView(
          error: snapshot.error!,
          onRetry: () => setState(
            () => _future = ref
                .read(profileTabsServiceProvider)
                .achievements(widget.userId),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final stats = data.stats;
      return RefreshIndicator(
        onRefresh: () async => setState(
          () => _future = ref
              .read(profileTabsServiceProvider)
              .achievements(widget.userId),
        ),
        child: ListView(
          key: PageStorageKey('profile-achievements-${widget.userId}'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      AppIcons.award,
                      color: _tierColor(data.tier),
                      size: 54,
                    ),
                    Text(
                      data.tier,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${data.totalPoints} điểm',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rank in data.ranks)
                  Chip(
                    label: Text(
                      '${rank.period}: ${rank.rank == null ? '—' : '#${rank.rank}'} · ${rank.points}đ',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _metric('Thắng', stats.wins),
                    _metric('Hòa', stats.draws),
                    _metric('Thua', stats.losses),
                    _metric('Trận', stats.matchesPlayed),
                    _metric('Vô địch', stats.tournamentTitles),
                    _metric('Á quân', stats.tournamentRunnerUps),
                  ],
                ),
              ),
            ),
            if (data.recentTransactions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Lịch sử điểm',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final tx in data.recentTransactions)
                ListTile(
                  title: Text(tx.reason),
                  leading: CircleAvatar(
                    child: Text('${tx.points >= 0 ? '+' : ''}${tx.points}'),
                  ),
                  subtitle: Text(
                    Dates.dateOnly(
                      tx.occurredAt,
                      locale: Localizations.localeOf(context).languageCode,
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

Widget _metric(String label, int value) => SizedBox(
  width: 86,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
      Text(label),
    ],
  ),
);
Color _tierColor(String tier) => switch (tier) {
  'GOLD' => Colors.amber,
  'SILVER' => Colors.blueGrey,
  'PLATINUM' => Colors.cyan,
  'DIAMOND' => Colors.blue,
  _ => Colors.brown,
};

class _HostedTab extends ConsumerStatefulWidget {
  const _HostedTab({required this.userId});
  final String userId;
  @override
  ConsumerState<_HostedTab> createState() => _HostedTabState();
}

class _HostedTabState extends ConsumerState<_HostedTab> {
  var _filter = 'active';
  late Future<List<Session>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Session>> _load() async =>
      (await ref
              .read(profileTabsServiceProvider)
              .hosted(widget.userId, filter: _filter))
          .items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'active', label: Text('Đang hoạt động')),
            ButtonSegment(value: 'ended', label: Text('Đã kết thúc')),
            ButtonSegment(value: 'all', label: Text('Tất cả')),
          ],
          selected: {_filter},
          onSelectionChanged: (value) => setState(() {
            _filter = value.first;
            _future = _load();
          }),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Session>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorView(
                error: snapshot.error!,
                onRetry: () => setState(() => _future = _load()),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const _Empty('Không có kèo đã host.');
            }
            return ListView.separated(
              key: PageStorageKey(
                'profile-hosted-${widget.userId}-$_filter',
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final session = snapshot.data![index];
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
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
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
            if (all.isEmpty) const _Empty('Chưa tham gia nhóm nào.'),
            if (hosted.isNotEmpty || widget.owner)
              _clubGroup(context, 'Nhóm đã host', hosted),
            if (widget.owner && member.isNotEmpty)
              _clubGroup(context, 'Nhóm đã tham gia', member),
          ],
        ),
      );
    },
  );
}

Widget _clubGroup(
  BuildContext context,
  String title,
  List<ClubSummary> clubs,
) => Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${clubs.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (clubs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Chưa có nhóm.'),
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
            subtitle: Text('${club.memberCount} thành viên'),
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
            'Điểm trung bình: ${bundle.stats.average.toStringAsFixed(1)}',
          ),
          subtitle: Text('${bundle.stats.total} đánh giá'),
        ),
      ),
      if (bundle.ratings.isEmpty)
        const _Empty('Chưa có đánh giá.')
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
              title: Text(rating.raterName ?? 'Vmito'),
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

class _FavoritesTab extends ConsumerStatefulWidget {
  const _FavoritesTab({required this.userId});
  final String userId;
  @override
  ConsumerState<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends ConsumerState<_FavoritesTab> {
  var _type = 'SESSION';
  late Future<List<FavoriteTarget>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FavoriteTarget>> _load() async =>
      (await ref.read(profileTabsServiceProvider).favorites(_type)).items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'SESSION', label: Text('Kèo')),
            ButtonSegment(value: 'VENUE', label: Text('Sân')),
            ButtonSegment(value: 'CLUB', label: Text('Nhóm')),
            ButtonSegment(value: 'TOURNAMENT', label: Text('Giải')),
          ],
          selected: {_type},
          onSelectionChanged: (value) => setState(() {
            _type = value.first;
            _future = _load();
          }),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<FavoriteTarget>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorView(
                error: snapshot.error!,
                onRetry: () => setState(() => _future = _load()),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const _Empty('Chưa có mục yêu thích.');
            }
            return ListView.separated(
              key: PageStorageKey(
                'profile-favorites-${widget.userId}-$_type',
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = snapshot.data![index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: item.image == null
                        ? null
                        : CachedNetworkImageProvider(item.image!),
                    child: item.image == null
                        ? const Icon(AppIcons.favorite)
                        : null,
                  ),
                  title: Text(item.name),
                  subtitle: item.subtitle == null ? null : Text(item.subtitle!),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => _open(context, item),
                );
              },
            );
          },
        ),
      ),
    ],
  );
  void _open(BuildContext context, FavoriteTarget item) {
    final id = item.slug ?? item.id;
    if (_type == 'VENUE') {
      unawaited(context.push(AppRoutes.venueDetail(id)));
    } else if (_type == 'CLUB') {
      unawaited(context.push(AppRoutes.clubDetail(id)));
    } else if (_type == 'SESSION') {
      unawaited(context.push(AppRoutes.sessionDetail(id)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chi tiết giải đấu chưa có trên mobile.')),
      );
    }
  }
}
