import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';

class BrowseClubsScreen extends ConsumerStatefulWidget {
  const BrowseClubsScreen({
    this.embedded = false,
    this.discoveryHeader,
    super.key,
  });

  /// Omits this feature's Scaffold/AppBar when it is hosted by Home's
  /// discovery switcher.
  final bool embedded;
  final Widget? discoveryHeader;

  @override
  ConsumerState<BrowseClubsScreen> createState() => _BrowseClubsScreenState();
}

class _BrowseClubsScreenState extends ConsumerState<BrowseClubsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 380) {
        unawaited(ref.read(clubsControllerProvider.notifier).loadMore());
      }
    });
    Future<void>.microtask(
      () => ref.read(clubsControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubsControllerProvider);
    final discoveryHeader = widget.discoveryHeader;
    final headerCount = discoveryHeader == null ? 0 : 1;
    final footerIndex = state.clubs.length + headerCount + 1;
    final body = RefreshIndicator(
      onRefresh: () =>
          ref.read(clubsControllerProvider.notifier).load(search: state.search),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: state.clubs.length + headerCount + 2,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return SearchBar(
                  controller: _search,
                  hintText: 'Tìm câu lạc bộ',
                  leading: const Icon(AppIcons.search),
                  onChanged: (value) {
                    _timer?.cancel();
                    _timer = Timer(
                      const Duration(milliseconds: 400),
                      () => ref
                          .read(clubsControllerProvider.notifier)
                          .load(search: value),
                    );
                  },
                );
              }
              if (index == 1 && discoveryHeader != null) {
                return discoveryHeader;
              }
              if (index == footerIndex) {
                if (state.isLoading && state.clubs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
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
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Không tìm thấy câu lạc bộ.')),
                  );
                }
                return state.isLoading && state.clubs.isNotEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink();
              }
              return _ClubBrowseCard(
                club: state.clubs[index - headerCount - 1],
              );
            },
          ),
        ),
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Câu lạc bộ'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.tune),
            tooltip: 'Sắp xếp',
            onPressed: _sort,
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _sort() => showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Sắp xếp',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final option in const [
            ('Phổ biến nhất', 'sessionCount'),
            ('Mới nhất', 'createdAt'),
            ('Tên A–Z', 'name'),
          ])
            ListTile(
              title: Text(option.$1),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(clubsControllerProvider.notifier)
                    .load(search: ref.read(clubsControllerProvider).search);
              },
            ),
        ],
      ),
    ),
  );
}

class _ClubBrowseCard extends StatelessWidget {
  const _ClubBrowseCard({required this.club});
  final ClubSummary club;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push(AppRoutes.clubDetail(club.slug ?? club.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 145,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (club.heroImage != null)
                  CachedNetworkImage(
                    imageUrl: club.heroImage!,
                    fit: BoxFit.cover,
                  )
                else
                  ColoredBox(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FavoriteButton(
                    type: FavoriteType.club,
                    targetId: club.id,
                    onSignInRequired: () => context.push(AppRoutes.signIn),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: club.logo == null
                      ? null
                      : CachedNetworkImageProvider(club.logo!),
                  child: club.logo == null
                      ? const Icon(AppIcons.clubs)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${club.memberCount} thành viên',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (club.defaultVenue?.name ?? club.location
                          case final location?)
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
