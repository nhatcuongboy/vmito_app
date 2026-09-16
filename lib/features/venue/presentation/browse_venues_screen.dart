import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/constants/image_constants.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_permission_feedback.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_address_text.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/venue_card_skeleton.dart';
import 'package:vmito_app/features/venue/presentation/venue_filter_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_paginated_list_view.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';
import 'package:vmito_app/shared/widgets/discovery_entity_map_view.dart';
import 'package:vmito_app/shared/widgets/discovery_map_toggle.dart';

class BrowseVenuesScreen extends ConsumerStatefulWidget {
  const BrowseVenuesScreen({
    this.embedded = false,
    this.discoveryHeader,
    this.initialFilter,
    this.showFilterSummary = false,
    this.showMapToggle = false,
    super.key,
  });

  /// Omits this feature's Scaffold/AppBar when it is hosted by Home's
  /// discovery switcher.
  final bool embedded;
  final Widget? discoveryHeader;
  final VenueFilter? initialFilter;
  final bool showFilterSummary;
  final bool showMapToggle;

  @override
  ConsumerState<BrowseVenuesScreen> createState() => _BrowseVenuesScreenState();
}

class _BrowseVenuesScreenState extends ConsumerState<BrowseVenuesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  VoidCallback? _removeReselectHandler;
  var _showMap = false;
  var _isMapToggleExtended = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (widget.embedded) {
      _removeReselectHandler = ref
          .read(tabReselectionControllerProvider)
          .register(
            tabIndex: 0,
            onReselect: () => scrollToTop(_scroll),
          );
    }
    unawaited(Future<void>.microtask(_loadInitial));
  }

  /// Loads the first page with coordinates resolved beforehand when sorting by distance.
  ///
  /// The default sort is "Gần tôi nhất" (distance), which the backend only honours when
  /// coordinates are attached. Resolving coordinates before issuing the load avoids
  /// firing an uncoordinated request followed immediately by a coordinated re-sort,
  /// preventing double fetching and UI flickering.
  Future<void> _loadInitial() async {
    final controller = ref.read(venueBrowseControllerProvider.notifier);
    final currentState = ref.read(venueBrowseControllerProvider);
    final preferredCity = ref
        .read(locationPreferencesControllerProvider)
        .preferredCity;
    var filter =
        widget.initialFilter ??
        VenueFilter(
          city: preferredCity,
          latitude: currentState.filter.latitude,
          longitude: currentState.filter.longitude,
        );

    // Reuse existing coordinates if the filter does not have them yet.
    if (filter.latitude == null && filter.longitude == null) {
      if (currentState.filter.latitude != null &&
          currentState.filter.longitude != null) {
        filter = filter.copyWith(
          latitude: currentState.filter.latitude,
          longitude: currentState.filter.longitude,
        );
      }
    }

    final needsLocation =
        filter.sortBy == VenueSortOption.distance.value &&
        (filter.latitude == null || filter.longitude == null);

    if (needsLocation) {
      try {
        final coordinates = await ref
            .read(deviceLocationServiceProvider)
            .call();
        filter = filter.copyWith(
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        );
      } on Object {
        // No position available (permission denied, no fix).
        // Keep the filter as-is rather than surfacing an error on a silent background step.
      }
    }

    if (!mounted) return;
    await controller.load(filter: filter);
  }

  @override
  void dispose() {
    _removeReselectHandler?.call();
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 380) {
      unawaited(ref.read(venueBrowseControllerProvider.notifier).loadMore());
    }
  }

  Future<void> _nearMe() async {
    try {
      final coordinates = await ref.read(deviceLocationServiceProvider).call();
      final filter = ref
          .read(venueBrowseControllerProvider)
          .filter
          .copyWith(
            sortBy: 'distance',
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
          );
      await ref
          .read(venueBrowseControllerProvider.notifier)
          .load(filter: filter);
    } on LocationPermissionException {
      if (mounted) showLocationPermissionDeniedSnackBar(context);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(venueBrowseControllerProvider);
    ref.watch(locationPreferencesControllerProvider);
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _body(state),
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sân'),
        actions: [
          IconButton(
            onPressed: _createRequest,
            icon: const Icon(AppIcons.addLocation),
            tooltip: 'Đề xuất thêm sân',
          ),
          IconButton(
            onPressed: _nearMe,
            icon: const Icon(AppIcons.myLocation),
            tooltip: 'Gần tôi',
          ),
          IconButton(
            key: const Key('venue-filter-button'),
            onPressed: () => _openFilters(state.filter),
            icon: const Icon(AppIcons.tune),
            tooltip: AppLocalizations.of(context).venueFiltersTitle,
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _createRequest() async {
    final draft = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateVenueSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(venueServiceProvider)
          .createRequest(
            type: 'CREATE',
            payload: draft,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi đề xuất thêm sân.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      if (notification.metrics.pixels <= 0) {
        if (!_isMapToggleExtended) {
          setState(() => _isMapToggleExtended = true);
        }
      } else if (notification is UserScrollNotification) {
        if (notification.direction == ScrollDirection.reverse) {
          if (_isMapToggleExtended) {
            setState(() => _isMapToggleExtended = false);
          }
        } else if (notification.direction == ScrollDirection.forward) {
          if (!_isMapToggleExtended) {
            setState(() => _isMapToggleExtended = true);
          }
        }
      }
    }
    return false;
  }

  Widget _body(VenueBrowseState state) {
    final discoveryHeader = widget.discoveryHeader;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Column(
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
                      hintText: 'Tìm kiếm sân',
                      leading: const Icon(AppIcons.search),
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 400),
                          () => ref
                              .read(venueBrowseControllerProvider.notifier)
                              .load(
                                filter: state.filter.copyWith(
                                  keyword: value,
                                ),
                              ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filledTonal(
                    key: const Key('venue-inline-filter-button'),
                    tooltip: AppLocalizations.of(context).venueFiltersTitle,
                    icon: const Icon(AppIcons.tune),
                    onPressed: () => _openFilters(state.filter),
                  ),
                ],
              ),
            ),
          ?discoveryHeader,
          if (widget.showFilterSummary)
            _VenueFilterSummary(
              filter: state.filter,
              preferredCity: ref
                  .read(locationPreferencesControllerProvider)
                  .preferredCity,
              onChanged: (filter) => unawaited(
                ref
                    .read(venueBrowseControllerProvider.notifier)
                    .load(filter: filter),
              ),
            ),
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
                          items: _mapItems(state.venues),
                          emptyMessage: AppLocalizations.of(
                            context,
                          ).discoveryMapNoLocations,
                        )
                      : RefreshIndicator(
                          key: const Key('venue-refresh-indicator'),
                          onRefresh: () => ref
                              .read(venueBrowseControllerProvider.notifier)
                              .load(isPullToRefresh: true),
                          child: switch (state) {
                            _ when state.isLoading && state.venues.isEmpty =>
                              const _VenueListSkeleton(),
                            _
                                when state.error != null &&
                                    state.venues.isEmpty =>
                              _VenueListStatus(
                                child: AppErrorView(
                                  error: state.error!,
                                  onRetry: () => ref
                                      .read(
                                        venueBrowseControllerProvider.notifier,
                                      )
                                      .load(),
                                ),
                              ),
                            _ when state.venues.isEmpty =>
                              const _VenueListStatus(
                                child: Text('Không tìm thấy sân phù hợp.'),
                              ),
                            _ => AppPaginatedListView.separated(
                              controller: _scroll,
                              padding: const EdgeInsets.all(
                                AppSpacing.screenPadding,
                              ),
                              itemCount: state.venues.length,
                              hasMore: state.hasMore,
                              isLoading: state.isLoading,
                              isLoadingMore: state.isLoadingMore,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) =>
                                  VenueCard(venue: state.venues[index]),
                            ),
                          },
                        ),
                ),
                if (widget.embedded && widget.showMapToggle)
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: DiscoveryMapToggle(
                      key: const Key('venue-map-view-toggle'),
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

  Future<void> _openFilters(VenueFilter filter) async {
    final selected = await showAppFilterSheet<VenueFilter>(
      context,
      builder: (context) => VenueFilterSheet(
        initial: filter,
        preferredCity: ref
            .read(locationPreferencesControllerProvider)
            .preferredCity,
      ),
    );
    if (selected == null) return;
    await ref
        .read(venueBrowseControllerProvider.notifier)
        .load(filter: selected);
  }

  List<DiscoveryMapItem> _mapItems(List<Venue> venues) => venues
      .where((venue) => venue.lat != null && venue.lng != null)
      .map(
        (venue) => DiscoveryMapItem(
          id: venue.id,
          title: venue.name,
          subtitle: venue.address,
          latitude: venue.lat!,
          longitude: venue.lng!,
          onOpenDetail: () => context.push(AppRoutes.venueDetail(venue.id)),
        ),
      )
      .toList(growable: false);
}

class _VenueListStatus extends StatelessWidget {
  const _VenueListStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.xl),
    children: [Center(child: child)],
  );
}

class _VenueListSkeleton extends StatelessWidget {
  const _VenueListSkeleton();

  @override
  Widget build(BuildContext context) => const AppSkeletonList(
    listKey: Key('venue-skeleton-list'),
    itemBuilder: _buildCard,
  );

  static Widget _buildCard(BuildContext context) => const VenueCardSkeleton();
}

class _VenueFilterSummary extends StatelessWidget {
  const _VenueFilterSummary({
    required this.filter,
    required this.preferredCity,
    required this.onChanged,
  });

  final VenueFilter filter;
  final String? preferredCity;
  final ValueChanged<VenueFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final city = filter.city?.trim();
    final district = filter.district?.trim();
    final hasCity =
        city != null && city.isNotEmpty && city != preferredCity?.trim();
    final hasDistricts = filter.districts.isNotEmpty;
    final hasDistrict =
        !hasDistricts && district != null && district.isNotEmpty;
    final hasSports = filter.sports.isNotEmpty;
    final hasCourtCount = filter.courtCount != null;
    final hasSort = filter.sortBy != VenueSortOption.distance.value;
    if (!hasCity &&
        !hasDistrict &&
        !hasDistricts &&
        !hasSports &&
        !hasCourtCount &&
        !hasSort) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView(
        key: const Key('venue-filter-summary'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.xs,
        ),
        children: [
          if (hasSort)
            _SummaryChip(
              key: const Key('venue-sort-summary-chip'),
              label: VenueSortOption.fromValue(filter.sortBy).label(l10n),
              onDeleted: () => onChanged(
                filter.copyWith(
                  sortBy: VenueSortOption.distance.value,
                ),
              ),
            ),
          for (final sport in filter.sports)
            _SummaryChip(
              label: switch (sport) {
                VenueSport.badminton => l10n.sessionSportBadminton,
                VenueSport.pickleball => l10n.sessionSportPickleball,
              },
              onDeleted: () {
                final nextSports = {...filter.sports}..remove(sport);
                onChanged(
                  filter.copyWith(
                    sports: nextSports,
                    clearSports: nextSports.isEmpty,
                  ),
                );
              },
            ),
          if (hasCity)
            _SummaryChip(
              label: city,
              onDeleted: () => onChanged(
                preferredCity == null
                    ? filter.copyWith(
                        clearCity: true,
                        clearDistrict: true,
                        clearDistricts: true,
                      )
                    : filter.copyWith(
                        city: preferredCity,
                        clearDistrict: true,
                        clearDistricts: true,
                      ),
              ),
            ),
          if (hasDistricts)
            for (final d in filter.districts)
              _SummaryChip(
                label: d,
                onDeleted: () {
                  final next = {...filter.districts}..remove(d);
                  onChanged(
                    filter.copyWith(
                      districts: next,
                      clearDistricts: next.isEmpty,
                    ),
                  );
                },
              )
          else if (hasDistrict)
            _SummaryChip(
              label: district,
              onDeleted: () => onChanged(filter.copyWith(clearDistrict: true)),
            ),
          if (hasCourtCount)
            _SummaryChip(
              label: filter.courtCount == VenueCourtCountFilter.fourPlus
                  ? l10n.sessionFilterFourPlusCourts
                  : l10n.sessionFilterCourtCountValue(
                      filter.courtCount!.minCourts,
                    ),
              onDeleted: () => onChanged(
                filter.copyWith(clearCourtCount: true),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.onDeleted,
    super.key,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.xs),
    child: InputChip(label: Text(label), onDeleted: onDeleted),
  );
}

class VenueCard extends StatelessWidget {
  const VenueCard({required this.venue, super.key});
  final Venue venue;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final logoUrl = venue.logo?.trim().isNotEmpty ?? false
        ? venue.logo!.trim()
        : null;
    final openingHours = venue.openingHours?.trim() ?? '';
    final hasCourts = venue.numberOfCourts != null;
    final hasOpeningHours = openingHours.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.venueDetail(venue.slug ?? venue.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 144,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (venue.coverPhoto != null)
                    CachedNetworkImage(
                      imageUrl: venue.coverPhoto!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const _VenueCover(),
                    )
                  else
                    const _VenueCover(),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: FavoriteButton(
                      type: FavoriteType.venue,
                      targetId: venue.id,
                      initialIsFavorite: venue.isFavorite,
                      variant: FavoriteButtonVariant.card,
                      showCount: false,
                    ),
                  ),
                  if (venue.distance != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _badge(
                        AppIcons.navigation,
                        '${venue.distance!.toStringAsFixed(1)} km',
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
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: logoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: logoUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  const _VenueDefaultLogo(),
                            )
                          : const _VenueDefaultLogo(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                venue.name,
                                style: theme.textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (venue.hasAddressData)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  AppIcons.location,
                                  key: const Key('venue-address-location-icon'),
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: AppAddressText(
                                    address: venue.address,
                                    district: venue.district,
                                    city: venue.city,
                                    newAddress: venue.newAddress,
                                    newDistrict: venue.newDistrict,
                                    newCity: venue.newCity,
                                    showNewAddressBadge: false,
                                    maxLines: 2,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hasCourts || hasOpeningHours)
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Row(
                              children: [
                                if (hasOpeningHours)
                                  Expanded(
                                    child: _VenueMetaItem(
                                      key: const Key('venue-hours-meta'),
                                      icon: AppIcons.clock,
                                      label: openingHours,
                                    ),
                                  ),
                                if (hasCourts)
                                  Expanded(
                                    child: _VenueMetaItem(
                                      key: const Key('venue-courts-meta'),
                                      icon: AppIcons.grid2x2,
                                      label: l10n.venueCourtsValue(
                                        venue.numberOfCourts!,
                                      ),
                                    ),
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
          ],
        ),
      ),
    );
  }

  static Widget _badge(IconData icon, String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VenueMetaItem extends StatelessWidget {
  const _VenueMetaItem({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _VenueCover extends StatelessWidget {
  const _VenueCover();
  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: kDefaultCoverPhoto,
    fit: BoxFit.cover,
    errorWidget: (_, _, _) => ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: const Icon(AppIcons.sessions, size: 48),
    ),
  );
}

class _VenueDefaultLogo extends StatelessWidget {
  const _VenueDefaultLogo();
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.primary,
    child: const Icon(AppIcons.location, color: Colors.white),
  );
}

class _CreateVenueSheet extends StatefulWidget {
  const _CreateVenueSheet();
  @override
  State<_CreateVenueSheet> createState() => _CreateVenueSheetState();
}

class _CreateVenueSheetState extends State<_CreateVenueSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _ward = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _street.dispose();
    _city.dispose();
    _ward.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Đề xuất thêm sân',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên sân'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Nhập tên sân' : null,
            ),
            TextFormField(
              controller: _street,
              decoration: const InputDecoration(labelText: 'Số nhà, tên đường'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Nhập địa chỉ' : null,
            ),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'Tỉnh / thành phố',
              ),
              validator: (value) => value?.trim().isEmpty ?? true
                  ? 'Nhập tỉnh / thành phố'
                  : null,
            ),
            TextFormField(
              controller: _ward,
              decoration: const InputDecoration(labelText: 'Phường / xã'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Nhập phường / xã' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, {
                      'name': _name.text.trim(),
                      'street': _street.text.trim(),
                      'address': _street.text.trim(),
                      'newCity': _city.text.trim(),
                      'newDistrict': _ward.text.trim(),
                    });
                  }
                },
                child: const Text('Gửi đề xuất'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
