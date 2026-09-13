import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/constants/image_constants.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_browse_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';
import 'package:vmito_app/shared/widgets/discovery_entity_map_view.dart';
import 'package:vmito_app/shared/widgets/discovery_map_toggle.dart';

class BrowseTournamentsContent extends ConsumerStatefulWidget {
  const BrowseTournamentsContent({
    this.discoveryHeader,
    this.initialSearch = '',
    this.showMapToggle = false,
    super.key,
  });

  final Widget? discoveryHeader;
  final String initialSearch;
  final bool showMapToggle;

  @override
  ConsumerState<BrowseTournamentsContent> createState() =>
      _BrowseTournamentsContentState();
}

class _BrowseTournamentsContentState
    extends ConsumerState<BrowseTournamentsContent> {
  final _scrollController = ScrollController();
  late final VoidCallback _removeReselectHandler;
  var _showMap = false;
  var _isMapToggleExtended = true;

  @override
  void initState() {
    super.initState();
    _removeReselectHandler = ref
        .read(tabReselectionControllerProvider)
        .register(
          tabIndex: 0,
          onReselect: () => scrollToTop(_scrollController),
        );
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(tournamentBrowseControllerProvider.notifier)
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
    _removeReselectHandler();
    _scrollController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      if (notification.metrics.pixels <= 0) {
        if (!_isMapToggleExtended) {
          setState(() => _isMapToggleExtended = true);
        }
      } else if (notification is UserScrollNotification ||
          notification is ScrollUpdateNotification) {
        final scrollingDown = switch (notification) {
          UserScrollNotification(:final direction) =>
            direction == ScrollDirection.reverse,
          ScrollUpdateNotification(:final scrollDelta) =>
            (scrollDelta ?? 0) > 0,
          _ => false,
        };
        final scrollingUp = switch (notification) {
          UserScrollNotification(:final direction) =>
            direction == ScrollDirection.forward,
          ScrollUpdateNotification(:final scrollDelta) =>
            (scrollDelta ?? 0) < 0,
          _ => false,
        };
        if (scrollingDown) {
          if (_isMapToggleExtended) {
            setState(() => _isMapToggleExtended = false);
          }
        } else if (scrollingUp) {
          if (!_isMapToggleExtended) {
            setState(() => _isMapToggleExtended = true);
          }
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tournamentBrowseControllerProvider);
    final controller = ref.read(tournamentBrowseControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Column(
        children: [
          ?widget.discoveryHeader,
          if (!_showMap)
            SizedBox(
              height: 2,
              child: state.isRefetching
                  ? const LinearProgressIndicator()
                  : null,
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _showMap
                      ? DiscoveryEntityMapView(
                          items: _mapItems(state.tournaments),
                          emptyMessage: l10n.discoveryMapNoLocations,
                        )
                      : RefreshIndicator(
                          onRefresh: () =>
                              controller.load(isPullToRefresh: true),
                          child: switch (state) {
                            _
                                when state.isLoading &&
                                    state.tournaments.isEmpty =>
                              const _TournamentListSkeleton(),
                            _
                                when state.error != null &&
                                    state.tournaments.isEmpty =>
                              AppErrorView(
                                error: state.error!,
                                onRetry: controller.load,
                              ),
                            _ when state.tournaments.isEmpty => ListView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.25,
                                ),
                                Icon(
                                  AppIcons.trophy,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).extension<AppPalette>()!.mutedForeground,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  l10n.tournamentEmpty,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                            _ => ListView.separated(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: state.tournaments.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) =>
                                  TournamentBrowseCard(
                                    tournament: state.tournaments[index],
                                  ),
                            ),
                          },
                        ),
                ),
                if (widget.showMapToggle)
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: DiscoveryMapToggle(
                      key: const Key('tournament-map-view-toggle'),
                      showMap: _showMap,
                      isExtended: _isMapToggleExtended,
                      onPressed: () => setState(() {
                        _showMap = !_showMap;
                        _isMapToggleExtended = true;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DiscoveryMapItem> _mapItems(List<TournamentSummary> tournaments) =>
      tournaments
          .where((tournament) => tournament.hasVenueCoordinates)
          .map(
            (tournament) => DiscoveryMapItem(
              id: tournament.id,
              title: tournament.name,
              subtitle: tournament.venueName ?? tournament.location,
              latitude: tournament.venueLatitude!,
              longitude: tournament.venueLongitude!,
              onOpenDetail: () => context.push(
                AppRoutes.tournamentDetail(tournament.slug ?? tournament.id),
              ),
            ),
          )
          .toList(growable: false);
}

class _TournamentListSkeleton extends StatelessWidget {
  const _TournamentListSkeleton();

  @override
  Widget build(BuildContext context) => const AppSkeletonList(
    listKey: Key('tournament-skeleton-list'),
    itemBuilder: _buildCard,
  );

  static Widget _buildCard(BuildContext context) =>
      const TournamentBrowseCardSkeleton();
}

class TournamentBrowseCard extends ConsumerWidget {
  const TournamentBrowseCard({required this.tournament, super.key});

  final TournamentSummary tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final showNewAddress = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.tournamentDetail(tournament.slug ?? tournament.id),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (tournament.coverPhoto case final cover?)
                    CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const _TournamentPlaceholder(),
                    )
                  else
                    const _TournamentPlaceholder(),
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _statusColor(tournament.status, palette),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          _statusLabel(tournament.status, l10n),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: FavoriteButton(
                      key: ValueKey('tournament-favorite-${tournament.id}'),
                      type: FavoriteType.tournament,
                      targetId: tournament.id,
                      initialIsFavorite: tournament.isFavorite,
                      variant: FavoriteButtonVariant.card,
                      showCount: false,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournament.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MetadataLine(
                    icon: AppIcons.calendarMonth,
                    label: _dateRange(context, tournament),
                  ),
                  if (tournament.displayLocation(
                        showNewAddress: showNewAddress,
                      )
                      case final location?) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _MetadataLine(
                      icon: AppIcons.location,
                      label: location,
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

  static String _dateRange(
    BuildContext context,
    TournamentSummary tournament,
  ) {
    final localizations = MaterialLocalizations.of(context);
    final start = tournament.startDate.toLocal();
    final end = tournament.endDate.toLocal();
    final startLabel = localizations.formatMediumDate(start);
    if (DateUtils.isSameDay(start, end)) return startLabel;
    return '$startLabel – ${localizations.formatMediumDate(end)}';
  }

  static Color _statusColor(
    TournamentStatus status,
    AppPalette palette,
  ) => switch (status) {
    TournamentStatus.preparing => palette.success,
    TournamentStatus.inProgress => palette.warning,
    TournamentStatus.finished => palette.mutedForeground,
    TournamentStatus.cancelled => AppColors.destructive,
  };

  static String _statusLabel(
    TournamentStatus status,
    AppLocalizations l10n,
  ) => switch (status) {
    TournamentStatus.preparing => l10n.tournamentStatusPreparing,
    TournamentStatus.inProgress => l10n.tournamentStatusInProgress,
    TournamentStatus.finished => l10n.tournamentStatusFinished,
    TournamentStatus.cancelled => l10n.tournamentStatusCancelled,
  };
}

class _TournamentPlaceholder extends StatelessWidget {
  const _TournamentPlaceholder();

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: kDefaultCoverPhoto,
    fit: BoxFit.cover,
    errorWidget: (_, _, _) => ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: const Icon(AppIcons.trophy, size: 48),
    ),
  );
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
