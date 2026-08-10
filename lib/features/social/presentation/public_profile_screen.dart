import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
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
import 'package:vmito_app/features/social/presentation/widgets/social_post_card.dart';

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
  const PublicProfileScreen({required this.userId, super.key});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(publicProfileProvider(userId));
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: bundle.when(
        data: (data) => _ProfileTabs(userId: userId, bundle: data),
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
  const _ProfileTabs({required this.userId, required this.bundle});
  final String userId;
  final PublicProfileBundle bundle;

  @override
  ConsumerState<_ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends ConsumerState<_ProfileTabs>
    with TickerProviderStateMixin {
  late TabController _controller;
  late bool _owner;

  @override
  void initState() {
    super.initState();
    _owner = _isOwner;
    _controller = TabController(
      length: publicProfileTabLabels(isOwner: _owner).length,
      vsync: this,
    );
  }

  bool get _isOwner => ref.read(currentUserProvider)?.id == widget.userId;

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
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = publicProfileTabLabels(isOwner: _owner);
    return LayoutBuilder(
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            children: [
              _ProfileHeader(
                profile: widget.bundle.profile,
                bundle: widget.bundle,
              ),
              Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: TabBar(
                  controller: _controller,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final label in labels) Tab(text: label)],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _controller,
                  children: [
                    _PostsTab(userId: widget.userId),
                    _AchievementsTab(userId: widget.userId),
                    _HostedTab(userId: widget.userId),
                    _ClubsTab(userId: widget.userId, owner: _owner),
                    _ReviewsTab(bundle: widget.bundle),
                    if (_owner) const _FavoritesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.bundle});
  final PublicProfile profile;
  final PublicProfileBundle bundle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (profile.coverPhoto != null)
                CachedNetworkImage(
                  imageUrl: profile.coverPhoto!,
                  fit: BoxFit.cover,
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: profile.image == null
                        ? null
                        : CachedNetworkImageProvider(profile.image!),
                    child: profile.image == null
                        ? const Icon(AppIcons.profile, size: 48)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            children: [
              Text(
                profile.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(profile.role)),
                  if (profile.levelDescription != null)
                    Chip(label: Text(profile.levelDescription!)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat('${profile.joinedSessionsCount}', 'Kèo tham gia'),
                  _Stat(
                    bundle.stats.average.toStringAsFixed(1),
                    'Điểm đánh giá',
                  ),
                  _Stat('${bundle.stats.total}', 'Đánh giá'),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
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
  final _scroll = ScrollController();
  var _page = 1;
  var _more = true;
  var _loadingMore = false;
  var _posts = <SocialPost>[];
  late Future<void> _future;
  @override
  void initState() {
    super.initState();
    _future = _refresh();
    _scroll.addListener(_next);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final result = await ref
        .read(profileTabsServiceProvider)
        .posts(widget.userId);
    _posts = result.posts;
    _page = result.page;
    _more = result.hasMore;
  }

  void _next() {
    if (_scroll.position.extentAfter < 300 && _more && !_loadingMore) {
      unawaited(_loadMore());
    }
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
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_posts.isEmpty) return const _Empty('Chưa có bài viết.');
      return RefreshIndicator(
        onRefresh: () async => setState(() => _future = _refresh()),
        child: ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: _posts.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => index == _posts.length
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : SocialPostCard(
                  post: _posts[index],
                  onOpen: () =>
                      context.push(AppRoutes.socialPost(_posts[index].id)),
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
      if (all.isEmpty) return const _Empty('Chưa tham gia nhóm nào.');
      return RefreshIndicator(
        onRefresh: () async => setState(
          () => _future = ref
              .read(profileTabsServiceProvider)
              .clubs(widget.userId),
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
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
              child: club.logo == null
                  ? const Icon(AppIcons.clubs)
                  : null,
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
  const _FavoritesTab();
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
