import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/presentation/player/session_filter_sheet.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

/// Public-session browser embedded in Home discovery.
class BrowseSessionsContent extends ConsumerStatefulWidget {
  const BrowseSessionsContent({
    this.discoveryHeader,
    this.initialFilters = const BrowseSessionFilters(),
    super.key,
  });

  final Widget? discoveryHeader;
  final BrowseSessionFilters initialFilters;

  @override
  ConsumerState<BrowseSessionsContent> createState() =>
      _BrowseSessionsContentState();
}

class _BrowseSessionsContentState extends ConsumerState<BrowseSessionsContent> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // The controller cannot fetch in build(), so kick off the first load once
    // the frame is committed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoaded) {
        _hasLoaded = true;
        final city = ref
            .read(locationPreferencesControllerProvider)
            .preferredCity;
        unawaited(
          ref
              .read(browseSessionsControllerProvider.notifier)
              .load(
                filters: widget.initialFilters.copyWith(
                  city: city,
                  cityIsDefault: true,
                ),
              ),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    ref.watch(locationPreferencesControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
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
                  controller: _searchController,
                  hintText: l10n.sessionSearchHint,
                  leading: const Icon(AppIcons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(AppIcons.close),
                        onPressed: () {
                          _searchController.clear();
                          unawaited(controller.load(search: ''));
                          setState(() {});
                        },
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {});
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 400),
                      () => controller.load(search: value),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Badge(
                isLabelVisible: state.filters.activeCount > 0,
                label: Text('${state.filters.activeCount}'),
                child: IconButton.filledTonal(
                  tooltip: l10n.sessionFiltersTitle,
                  icon: const Icon(AppIcons.tune),
                  onPressed: () async {
                    final filters =
                        await showModalBottomSheet<BrowseSessionFilters>(
                          context: context,
                          useRootNavigator: true,
                          isScrollControlled: true,
                          builder: (context) => SessionFilterSheet(
                            initial: state.filters,
                          ),
                        );
                    if (filters != null) {
                      unawaited(controller.load(filters: filters));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
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
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: switch (state) {
              _ when state.isLoading && state.sessions.isEmpty =>
                const AppLoadingView(),
              // Only replace the list with a full-screen error when there is
              // nothing to show; a failed "load more" keeps the list and reports
              // itself through the app-wide error listener.
              _ when state.error != null && state.sessions.isEmpty =>
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
      ],
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
      padding: const EdgeInsets.all(AppSpacing.md),
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
