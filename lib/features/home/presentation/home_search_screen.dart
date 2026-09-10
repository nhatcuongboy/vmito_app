import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/home/application/home_search_history.dart';
import 'package:vmito_app/features/home/application/home_search_suggestions.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/domain/form/home_search_form.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/features/home/domain/home_search_outcome.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_featured_section.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_field.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_history_section.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_query_results.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// Search for one Home discovery tab. Pops with a [HomeSearchOutcome].
///
/// Mobile-only: the web app filters inline and has no search screen.
class HomeSearchScreen extends ConsumerStatefulWidget {
  const HomeSearchScreen({
    required this.tab,
    this.initialQuery = '',
    super.key,
  });

  final HomeDiscoveryTab tab;
  final String initialQuery;

  @override
  ConsumerState<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends ConsumerState<HomeSearchScreen> {
  late final FormGroup _form;
  late final StreamSubscription<Object?> _querySubscription;
  final _focusNode = FocusNode();
  Timer? _debounce;
  var _suggestions = const <DiscoverySuggestion>[];
  var _isFetching = false;
  var _hasFailed = false;
  var _requestGeneration = 0;
  var _showQueryError = false;

  FormControl<String> get _queryControl =>
      _form.control(HomeSearchControl.query) as FormControl<String>;

  String get _query => normalizeSearchQuery(_queryControl.value ?? '');

  @override
  void initState() {
    super.initState();
    _form = createHomeSearchForm(initialQuery: widget.initialQuery);
    _querySubscription = _queryControl.valueChanges.listen((_) {
      if (_showQueryError && _query.isNotEmpty) _showQueryError = false;
      _scheduleSuggestions();
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _scheduleSuggestions();
    });
  }

  @override
  void dispose() {
    _requestGeneration++;
    _debounce?.cancel();
    unawaited(_querySubscription.cancel());
    _focusNode.dispose();
    _form.dispose();
    super.dispose();
  }

  void _scheduleSuggestions() {
    _debounce?.cancel();
    final query = _query;
    final generation = ++_requestGeneration;
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _isFetching = false;
        _hasFailed = false;
      });
      return;
    }
    // Previous rows stay visible until the new ones land.
    setState(() => _isFetching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final suggestions = await ref
            .read(homeSearchSuggestionServiceProvider)
            .search(tab: widget.tab, query: query);
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _suggestions = suggestions;
          _isFetching = false;
          _hasFailed = false;
        });
      } on Object {
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _suggestions = const [];
          _isFetching = false;
          _hasFailed = true;
        });
      }
    });
  }

  Future<void> _submit([String? value]) async {
    final query = normalizeSearchQuery(value ?? _query);
    _queryControl.updateValue(query);
    _form.markAllAsTouched();
    if (query.isEmpty) {
      setState(() => _showQueryError = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
      return;
    }
    if (_form.invalid || _form.pending) return;
    await ref.read(homeSearchHistoryProvider.notifier).add(widget.tab, query);
    if (mounted) Navigator.of(context).pop(HomeSearchQuery(query));
  }

  void _clearQuery() {
    setState(() => _showQueryError = false);
    _queryControl
      ..updateValue('')
      ..markAsPristine()
      ..markAsUntouched();
    _focusNode.requestFocus();
  }

  void _openSuggestion(DiscoverySuggestion suggestion) {
    final id = suggestion.entityId;
    unawaited(
      context.push(switch (suggestion.tab) {
        HomeDiscoveryTab.sessions => AppRoutes.sessionDetail(id),
        HomeDiscoveryTab.venues => AppRoutes.venueDetail(id),
        HomeDiscoveryTab.clubs => AppRoutes.clubDetail(id),
        HomeDiscoveryTab.tournaments => AppRoutes.tournamentDetail(id),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history =
        ref.watch(homeSearchHistoryProvider)[widget.tab] ?? const [];
    final historyController = ref.read(homeSearchHistoryProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonClose,
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: AppReactiveForm<HomeSearchOutcome>(
          formGroup: _form,
          child: HomeSearchField(
            formControlName: HomeSearchControl.query,
            focusNode: _focusNode,
            hintText: switch (widget.tab) {
              HomeDiscoveryTab.sessions => l10n.homeSearchHintSessions,
              HomeDiscoveryTab.venues => l10n.homeSearchHintVenues,
              HomeDiscoveryTab.clubs => l10n.homeSearchHintClubs,
              HomeDiscoveryTab.tournaments => l10n.homeSearchHintTournaments,
            },
            showClear: _queryControl.value?.isNotEmpty ?? false,
            hasError: _showQueryError,
            onSubmitted: () => unawaited(_submit()),
            onClear: _clearQuery,
          ),
        ),
        actions: const [SizedBox(width: AppSpacing.screenPadding)],
        bottom: _showQueryError
            ? _QueryErrorBar(l10n.homeSearchRequired)
            : null,
      ),
      body: SafeArea(
        top: false,
        child: _query.isEmpty
            ? ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  if (history.isNotEmpty)
                    HomeSearchHistorySection(
                      history: history,
                      onSelected: (query) => unawaited(_submit(query)),
                      onRemove: (query) => unawaited(
                        historyController.remove(widget.tab, query),
                      ),
                      onClear: () =>
                          unawaited(historyController.clear(widget.tab)),
                    ),
                  HomeSearchFeaturedSection(
                    tab: widget.tab,
                    showTopGap: history.isNotEmpty,
                    onSeeAll: () => Navigator.of(
                      context,
                    ).pop(HomeSearchPreset(widget.tab)),
                    onOpen: _openSuggestion,
                  ),
                ],
              )
            : HomeSearchQueryResults(
                query: _query,
                items: _suggestions,
                isFetching: _isFetching,
                hasFailed: _hasFailed,
                onSubmit: () => unawaited(_submit()),
                onSuggestion: _openSuggestion,
              ),
      ),
    );
  }
}

class _QueryErrorBar extends StatelessWidget implements PreferredSizeWidget {
  const _QueryErrorBar(this.message);

  final String message;

  @override
  Size get preferredSize => const Size.fromHeight(28);

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        // Lines up with the text inside the field: leading button plus the
        // field's search icon.
        padding: const EdgeInsets.fromLTRB(
          AppSizes.appBarHeight + HomeSearchField.height,
          0,
          AppSpacing.screenPadding,
          AppSpacing.sm,
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    ),
  );
}
