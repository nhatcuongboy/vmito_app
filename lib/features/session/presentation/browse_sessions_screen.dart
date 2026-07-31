import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/application/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Public session browse — the entry point of the join funnel.
///
/// Reachable signed-out on purpose (App Store guideline 5.1.1(i)).
class BrowseSessionsScreen extends ConsumerStatefulWidget {
  const BrowseSessionsScreen({super.key});

  @override
  ConsumerState<BrowseSessionsScreen> createState() =>
      _BrowseSessionsScreenState();
}

class _BrowseSessionsScreenState extends ConsumerState<BrowseSessionsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // The controller cannot fetch in build(), so kick off the first load once
    // the frame is committed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(browseSessionsControllerProvider.notifier).load());
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessionBrowseTitle)),
      body: Column(
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
                    leading: const Icon(Icons.search_rounded),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
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
                const SizedBox(width: AppSpacing.sm),
                Badge(
                  isLabelVisible: state.filters.activeCount > 0,
                  label: Text('${state.filters.activeCount}'),
                  child: IconButton.filledTonal(
                    tooltip: l10n.sessionFiltersTitle,
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () async {
                      final filters =
                          await showModalBottomSheet<BrowseSessionFilters>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => _FilterSheet(
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: switch (state) {
                _ when state.isLoading && state.sessions.isEmpty =>
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
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
      ),
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
            child: Center(child: CircularProgressIndicator()),
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
          Icons.search_off_rounded,
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

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final BrowseSessionFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late int? _level = widget.initial.level;
  late bool _hasSlots = widget.initial.hasSlots;
  late SessionSource _source = widget.initial.source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.sessionFiltersTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.sessionFilterSource,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<SessionSource>(
                segments: [
                  ButtonSegment(
                    value: SessionSource.all,
                    label: Text(l10n.sessionSourceAll),
                  ),
                  ButtonSegment(
                    value: SessionSource.regular,
                    label: Text(l10n.sessionSourceRegular),
                  ),
                  ButtonSegment(
                    value: SessionSource.facebook,
                    label: Text(l10n.sessionSourceFacebook),
                  ),
                ],
                selected: {_source},
                onSelectionChanged: (value) =>
                    setState(() => _source = value.single),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.sessionFilterLevel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final level in [9, 1, 10, 2, 3, 4, 5, 6, 7, 8])
                    FilterChip(
                      label: Text(l10n.levelName(level)),
                      selected: _level == level,
                      onSelected: (selected) =>
                          setState(() => _level = selected ? level : null),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.sessionFilterAvailableSlots),
                value: _hasSlots,
                onChanged: (value) => setState(() => _hasSlots = value),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      BrowseSessionFilters(search: widget.initial.search),
                    ),
                    child: Text(l10n.sessionFiltersClear),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      BrowseSessionFilters(
                        search: widget.initial.search,
                        level: _level,
                        hasSlots: _hasSlots,
                        source: _source,
                      ),
                    ),
                    child: Text(l10n.sessionFiltersApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
