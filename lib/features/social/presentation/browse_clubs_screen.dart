import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/constants/image_constants.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_schedule_formatter.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_empty_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_paginated_list_view.dart';
import 'package:vmito_app/shared/widgets/discovery_entity_map_view.dart';
import 'package:vmito_app/shared/widgets/discovery_map_toggle.dart';

class BrowseClubsScreen extends ConsumerStatefulWidget {
  const BrowseClubsScreen({
    this.embedded = false,
    this.discoveryHeader,
    this.initialSearch = '',
    this.showMapToggle = false,
    super.key,
  });

  /// Omits this feature's Scaffold/AppBar when it is hosted by Home's
  /// discovery switcher.
  final bool embedded;
  final Widget? discoveryHeader;
  final String initialSearch;
  final bool showMapToggle;

  @override
  ConsumerState<BrowseClubsScreen> createState() => _BrowseClubsScreenState();
}

class _BrowseClubsScreenState extends ConsumerState<BrowseClubsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  VoidCallback? _removeReselectHandler;
  var _showMap = false;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 380) {
        unawaited(ref.read(clubsControllerProvider.notifier).loadMore());
      }
    });
    if (widget.embedded) {
      _removeReselectHandler = ref
          .read(tabReselectionControllerProvider)
          .register(
            tabIndex: 0,
            onReselect: () => scrollToTop(_scroll),
          );
    }
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(clubsControllerProvider.notifier)
            .load(
              search: widget.initialSearch,
              city: ref
                  .read(locationPreferencesControllerProvider)
                  .preferredCity,
            ),
      ),
    );
  }

  @override
  void dispose() {
    _removeReselectHandler?.call();
    _timer?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubsControllerProvider);
    ref.watch(locationPreferencesControllerProvider);
    final discoveryHeader = widget.discoveryHeader;

    final content = Column(
      children: [
        if (!widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SearchBar(
                    controller: _search,
                    hintText: 'Tìm kiếm nhóm',
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
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  tooltip: 'Bộ lọc',
                  icon: const Icon(AppIcons.tune),
                  onPressed: () => AppEmptyFilterSheet.show(context),
                ),
              ],
            ),
          ),
        ?discoveryHeader,
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref
                .read(clubsControllerProvider.notifier)
                .load(search: state.search),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _showMap
                      ? DiscoveryEntityMapView(
                          items: _mapItems(state.clubs),
                          emptyMessage: AppLocalizations.of(
                            context,
                          ).discoveryMapNoLocations,
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: switch (state) {
                              _ when state.isLoading && state.clubs.isEmpty =>
                                const _ClubListStatus(
                                  child: CircularProgressIndicator(),
                                ),
                              _
                                  when state.error != null &&
                                      state.clubs.isEmpty =>
                                _ClubListStatus(
                                  child: AppErrorView(
                                    error: state.error!,
                                    onRetry: () => ref
                                        .read(
                                          clubsControllerProvider.notifier,
                                        )
                                        .load(search: state.search),
                                  ),
                                ),
                              _ when state.clubs.isEmpty =>
                                const _ClubListStatus(
                                  child: Text(
                                    'Không tìm thấy câu lạc bộ.',
                                  ),
                                ),
                              _ => AppPaginatedListView.separated(
                                controller: _scroll,
                                padding: const EdgeInsets.all(
                                  AppSpacing.screenPadding,
                                ),
                                itemCount: state.clubs.length,
                                hasMore: state.hasMore,
                                isLoading: state.isLoading,
                                isLoadingMore:
                                    state.isLoading && state.page > 0,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpacing.md),
                                itemBuilder: (context, index) =>
                                    _ClubBrowseCard(
                                      club: state.clubs[index],
                                    ),
                              ),
                            },
                          ),
                        ),
                ),
                if (widget.embedded && widget.showMapToggle)
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: DiscoveryMapToggle(
                      key: const Key('club-map-view-toggle'),
                      showMap: _showMap,
                      onPressed: () => setState(() => _showMap = !_showMap),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return content;

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
      body: content,
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
                unawaited(
                  ref
                      .read(clubsControllerProvider.notifier)
                      .load(search: ref.read(clubsControllerProvider).search),
                );
              },
            ),
        ],
      ),
    ),
  );

  List<DiscoveryMapItem> _mapItems(List<ClubSummary> clubs) => clubs
      .where((club) => club.defaultVenue?.hasCoordinates ?? false)
      .map(
        (club) {
          final venue = club.defaultVenue!;
          return DiscoveryMapItem(
            id: club.id,
            title: club.name,
            subtitle: venue.name,
            latitude: venue.latitude!,
            longitude: venue.longitude!,
            onOpenDetail: () =>
                context.push(AppRoutes.clubDetail(club.slug ?? club.id)),
          );
        },
      )
      .toList(growable: false);
}

class _ClubListStatus extends StatelessWidget {
  const _ClubListStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.xl),
    children: [Center(child: child)],
  );
}

class _ClubBrowseCard extends StatelessWidget {
  const _ClubBrowseCard({required this.club});
  final ClubSummary club;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = club.defaultVenue?.name ?? club.location;
    final schedule = formatClubActivitySchedule(club.schedules, l10n);

    return Card(
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
                      errorWidget: (_, _, _) => CachedNetworkImage(
                        imageUrl: kDefaultCoverPhoto,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => ColoredBox(
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: kDefaultCoverPhoto,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => ColoredBox(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: FavoriteButton(
                      type: FavoriteType.club,
                      targetId: club.id,
                      initialIsFavorite: club.isFavorite,
                      variant: FavoriteButtonVariant.card,
                      showCount: false,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: const Key('club-card-logo'),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: club.logo == null
                          ? null
                          : CachedNetworkImageProvider(club.logo!),
                      child: club.logo == null
                          ? const Icon(AppIcons.clubs)
                          : null,
                    ),
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
                        const SizedBox(height: 6),
                        if (location case final value?)
                          _ClubMetaRow(
                            key: const Key('club-card-location'),
                            icon: AppIcons.location,
                            text: value,
                          ),
                        _ClubMetaRow(
                          key: const Key('club-card-schedule'),
                          icon: AppIcons.clock,
                          text: schedule ?? l10n.socialNoActivitySchedule,
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
}

class _ClubMetaRow extends StatelessWidget {
  const _ClubMetaRow({
    required this.icon,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
