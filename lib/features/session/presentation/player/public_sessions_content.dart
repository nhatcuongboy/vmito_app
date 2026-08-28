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
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/domain/session_map_location.dart';
import 'package:vmito_app/features/session/presentation/player/session_map_view.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

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
                          _ when state.isLoading && state.sessions.isEmpty =>
                            const AppLoadingView(),
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
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.md,
                  child: Center(
                    child: _MapViewSwitcher(
                      showMap: _showMap,
                      onPressed: _toggleMap,
                    ),
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

/// Shows the destination view, so exactly one primary action is visible.
class _MapViewSwitcher extends StatelessWidget {
  const _MapViewSwitcher({required this.showMap, required this.onPressed});

  final bool showMap;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = showMap ? l10n.sessionMapShowList : l10n.sessionMapShow;
    final icon = showMap ? AppIcons.list : AppIcons.mapPin;

    return FilledButton.tonalIcon(
      key: const Key('session-map-view-toggle'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(112, AppSizes.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        elevation: 3,
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
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
      child: _MapViewSwitcher(
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

class _SessionList extends StatelessWidget {
  const _SessionList({required this.controller, required this.state});

  final ScrollController controller;
  final BrowseSessionsState state;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      // Always scrollable, or RefreshIndicator cannot be pulled on a short list.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        88,
      ),
      itemCount: state.sessions.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index >= state.sessions.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: AppLoadingView(),
          );
        }
        final session = state.sessions[index];
        return SessionCard(
          session: session,
          onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
        );
      },
    );
  }
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
