import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/domain/session_map_location.dart';
import 'package:vmito_app/features/session/presentation/player/session_map_view.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card_skeleton.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';
import 'package:vmito_app/shared/widgets/app_paginated_list_view.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';
import 'package:vmito_app/shared/widgets/discovery_map_toggle.dart';

/// Public-session browser embedded in Home discovery.
class BrowseSessionsContent extends ConsumerStatefulWidget {
  const BrowseSessionsContent({
    this.discoveryHeader,
    this.initialFilters = const BrowseSessionFilters(),
    this.onMapModeChanged,
    this.showMapToggle = false,
    super.key,
  });

  final Widget? discoveryHeader;
  final BrowseSessionFilters initialFilters;
  final ValueChanged<bool>? onMapModeChanged;
  final bool showMapToggle;

  @override
  ConsumerState<BrowseSessionsContent> createState() =>
      _BrowseSessionsContentState();
}

class _BrowseSessionsContentState extends ConsumerState<BrowseSessionsContent> {
  final _scrollController = ScrollController();
  bool _hasLoaded = false;
  bool _showMap = false;
  late final VoidCallback _removeReselectHandler;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _removeReselectHandler = ref
        .read(tabReselectionControllerProvider)
        .register(
          tabIndex: 0,
          onReselect: () => scrollToTop(_scrollController),
        );
    // The controller cannot fetch in build(), so kick off the first load once
    // the frame is committed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoaded) {
        _hasLoaded = true;
        final city = ref
            .read(locationPreferencesControllerProvider)
            .preferredCity;
        final initial = widget.initialFilters;
        unawaited(
          ref
              .read(browseSessionsControllerProvider.notifier)
              .load(
                filters: initial.copyWith(
                  city: initial.city ?? city,
                  cityIsDefault: initial.city == null || initial.cityIsDefault,
                ),
              ),
        );
      }
    });
  }

  @override
  void dispose() {
    _removeReselectHandler();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BrowseSessionsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showMapToggle && !widget.showMapToggle && _showMap) {
      _showMap = false;
      widget.onMapModeChanged?.call(false);
    }
  }

  void _onScroll() {
    // Prefetch a screenful early so the list rarely shows a spinner.
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      unawaited(
        ref.read(browseSessionsControllerProvider.notifier).loadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browseSessionsControllerProvider);
    final controller = ref.read(browseSessionsControllerProvider.notifier);
    ref
      ..watch(locationPreferencesControllerProvider)
      ..listen(browseSessionsControllerProvider, (previous, next) {
        if (_showMap && previous?.filters != next.filters) {
          unawaited(controller.loadMap());
        }
      });
    return Column(
      children: [
        ?widget.discoveryHeader,
        if (state.filters.venueId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                key: const Key('session-venue-filter-chip'),
                avatar: const Icon(AppIcons.location, size: 18),
                label: Text(
                  state.filters.venueName?.trim().isNotEmpty ?? false
                      ? state.filters.venueName!
                      : state.filters.venueId!,
                ),
                onDeleted: () => unawaited(
                  controller.load(
                    filters: state.filters.copyWith(clearVenue: true),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _showMap
                    ? _SessionMapBody(state: state, controller: controller)
                    : RefreshIndicator(
                        onRefresh: controller.refresh,
                        child: switch (state) {
                          _
                              when (!_hasLoaded || state.isLoading) &&
                                  state.sessions.isEmpty =>
                            const _SessionListSkeleton(),
                          // Only replace the list with a full-screen error when
                          // there is nothing to show; a failed "load more" keeps
                          // the list and reports itself through the app-wide
                          // error listener.
                          _
                              when state.error != null &&
                                  state.sessions.isEmpty =>
                            AppErrorView(
                              error: state.error!,
                              onRetry: controller.refresh,
                            ),
                          _ when state.isEmpty => const _EmptyView(),
                          _ => _SessionList(
                            controller: _scrollController,
                            state: state,
                          ),
                        },
                      ),
              ),
              if (widget.showMapToggle)
                Positioned(
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: DiscoveryMapToggle(
                    key: const Key('session-map-view-toggle'),
                    showMap: _showMap,
                    onPressed: _toggleMap,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleMap() {
    setState(() => _showMap = !_showMap);
    widget.onMapModeChanged?.call(_showMap);
    if (_showMap) {
      unawaited(
        ref.read(browseSessionsControllerProvider.notifier).loadMap(),
      );
    }
  }
}

@Preview(
  name: 'Map action',
  group: 'Session discovery',
  size: Size(360, 160),
)
Widget sessionMapViewSwitcherPreview() => MaterialApp(
  locale: const Locale('vi'),
  theme: ThemeData(useMaterial3: true),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Center(
      child: DiscoveryMapToggle(
        showMap: true,
        onPressed: _ignorePreviewMapModeChange,
      ),
    ),
  ),
);

void _ignorePreviewMapModeChange() {}

class _SessionMapBody extends StatelessWidget {
  const _SessionMapBody({required this.state, required this.controller});

  final BrowseSessionsState state;
  final BrowseSessionsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isMapLoading && state.mapSessions.isEmpty) {
      return const AppLoadingView();
    }
    if (state.mapError != null && state.mapSessions.isEmpty) {
      return AppErrorView(error: state.mapError!, onRetry: controller.loadMap);
    }
    return SessionMapView(
      locations: groupSessionsByMapLocation(state.mapSessions),
    );
  }
}

class _SessionList extends ConsumerWidget {
  const _SessionList({required this.controller, required this.state});

  final ScrollController controller;
  final BrowseSessionsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationStatuses =
        ref.watch(myRegistrationStatusesProvider).value ?? const {};
    final hostIds =
        state.sessions
            .map((session) => session.hostId)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    final hostRatings = hostIds.isEmpty
        ? const <String, RatingStats>{}
        : ref.watch(batchRatingStatsProvider(hostIds.join(','))).value ??
              const <String, RatingStats>{};
    return AppPaginatedListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        88,
      ),
      itemCount: state.sessions.length,
      hasMore: state.hasMore,
      isLoading: state.isLoading,
      isLoadingMore: state.isLoadingMore,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final session = state.sessions[index];
        return SessionCard(
          session: session,
          variant: SessionCardVariant.browse,
          showFavorite: true,
          hostRating: session.hostId == null
              ? null
              : hostRatings[session.hostId],
          registrationStatus: registrationStatuses[session.id],
          registrationBadgeAtBottom: true,
          onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
        );
      },
    );
  }
}

class _SessionListSkeleton extends StatelessWidget {
  const _SessionListSkeleton();

  @override
  Widget build(BuildContext context) => const AppSkeletonList(
    listKey: Key('browse-sessions-skeleton-list'),
    itemExtentEstimate: 190,
    padding: EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      88,
    ),
    itemBuilder: _buildCard,
  );

  static Widget _buildCard(BuildContext context) => const SessionCardSkeleton(
    variant: SessionCardVariant.browse,
    showFavorite: true,
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;

    // Still a scrollable, so pull-to-refresh works from the empty state.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
        Icon(
          AppIcons.searchOff,
          size: 48,
          color: palette.mutedForeground,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppLocalizations.of(context).sessionEmpty,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
