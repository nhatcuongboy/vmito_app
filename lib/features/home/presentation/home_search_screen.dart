import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/home/application/home_search_history.dart';
import 'package:vmito_app/features/home/application/home_search_suggestions.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/domain/form/home_search_form.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

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
  AsyncValue<List<DiscoverySuggestion>> _suggestions = const AsyncData([]);
  var _requestGeneration = 0;
  var _showQueryError = false;

  FormControl<String> get _queryControl =>
      _form.control(HomeSearchControl.query) as FormControl<String>;

  String get _query => normalizeSearchQuery(_queryControl.value ?? '');

  String get _searchHint => switch (widget.tab) {
    HomeDiscoveryTab.sessions => 'Tìm kiếm kèo',
    HomeDiscoveryTab.venues => 'Tìm kiếm sân',
    HomeDiscoveryTab.clubs => 'Tìm kiếm nhóm',
    HomeDiscoveryTab.tournaments => 'Tìm kiếm giải',
  };

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
      setState(() => _suggestions = const AsyncData([]));
      return;
    }
    setState(() => _suggestions = const AsyncLoading());
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final suggestions = await ref
            .read(homeSearchSuggestionServiceProvider)
            .search(
              tab: widget.tab,
              query: query,
              city: ref
                  .read(locationPreferencesControllerProvider)
                  .preferredCity,
            );
        if (!mounted || generation != _requestGeneration) return;
        setState(() => _suggestions = AsyncData(suggestions));
      } on Object catch (error, stackTrace) {
        if (!mounted || generation != _requestGeneration) return;
        setState(() => _suggestions = AsyncError(error, stackTrace));
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
    if (mounted) Navigator.of(context).pop(query);
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
    switch (suggestion.tab) {
      case HomeDiscoveryTab.sessions:
        unawaited(context.push(AppRoutes.sessionDetail(suggestion.entityId)));
      case HomeDiscoveryTab.venues:
        unawaited(context.push(AppRoutes.venueDetail(suggestion.entityId)));
      case HomeDiscoveryTab.clubs:
        unawaited(context.push(AppRoutes.clubDetail(suggestion.entityId)));
      case HomeDiscoveryTab.tournaments:
        unawaited(
          context.push(AppRoutes.tournamentDetail(suggestion.entityId)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searchBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: _showQueryError
          ? BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5)
          : BorderSide.none,
    );
    final history =
        ref.watch(homeSearchHistoryProvider)[widget.tab] ?? const [];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonClose,
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: ReactiveForm(
          formGroup: _form,
          child: ReactiveTextField<String>(
            key: const Key('home-search-field'),
            formControlName: HomeSearchControl.query,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => unawaited(_submit()),
            showErrors: (_) => false,
            validationMessages: {
              ValidationMessage.required: (_) => l10n.homeSearchRequired,
            },
            decoration: InputDecoration(
              hintText: _searchHint,
              prefixIcon: const Icon(AppIcons.search),
              suffixIcon: _queryControl.value?.isNotEmpty ?? false
                  ? IconButton(
                      key: const Key('home-search-clear-query'),
                      tooltip: l10n.homeSearchClearQuery,
                      icon: const Icon(AppIcons.close),
                      onPressed: _clearQuery,
                    )
                  : null,
              filled: true,
              border: searchBorder,
              enabledBorder: searchBorder,
              focusedBorder: _showQueryError ? searchBorder : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        actions: const [SizedBox(width: AppSpacing.sm)],
        bottom: _showQueryError
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Semantics(
                  liveRegion: true,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(72, 0, 16, 10),
                      child: Text(
                        l10n.homeSearchRequired,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: _query.isEmpty
            ? _HistoryView(
                history: history,
                onSelected: (query) => unawaited(_submit(query)),
                onRemove: (query) => unawaited(
                  ref
                      .read(homeSearchHistoryProvider.notifier)
                      .remove(widget.tab, query),
                ),
                onClear: history.isEmpty
                    ? null
                    : () => unawaited(
                        ref
                            .read(homeSearchHistoryProvider.notifier)
                            .clear(widget.tab),
                      ),
              )
            : _SuggestionView(
                query: _query,
                suggestions: _suggestions,
                onSubmit: () => unawaited(_submit()),
                onSuggestion: _openSuggestion,
              ),
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.history,
    required this.onSelected,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemove;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        if (history.isNotEmpty)
          ListTile(
            title: Text(
              l10n.homeSearchRecent,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: TextButton(
              onPressed: onClear,
              child: Text(l10n.homeSearchClearAll),
            ),
          ),
        for (final query in history)
          ListTile(
            leading: const Icon(AppIcons.history),
            title: Text(query),
            onTap: () => onSelected(query),
            trailing: IconButton(
              tooltip: l10n.homeSearchRemoveHistory,
              icon: const Icon(AppIcons.close),
              onPressed: () => onRemove(query),
            ),
          ),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              l10n.homeSearchNoRecent,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _SuggestionView extends StatelessWidget {
  const _SuggestionView({
    required this.query,
    required this.suggestions,
    required this.onSubmit,
    required this.onSuggestion,
  });

  final String query;
  final AsyncValue<List<DiscoverySuggestion>> suggestions;
  final VoidCallback onSubmit;
  final ValueChanged<DiscoverySuggestion> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      children: [
        ListTile(
          key: const Key('home-search-submit-suggestion'),
          leading: const CircleAvatar(child: Icon(AppIcons.search)),
          title: Text(l10n.homeSearchForQuery(query)),
          onTap: onSubmit,
        ),
        ...suggestions.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                l10n.homeSearchSuggestionsFailed,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          data: (items) => [
            for (final suggestion in items)
              ListTile(
                leading: _SuggestionAvatar(suggestion: suggestion),
                title: Text(suggestion.title),
                subtitle: suggestion.subtitle?.trim().isNotEmpty ?? false
                    ? Text(
                        suggestion.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () => onSuggestion(suggestion),
              ),
            if (items.isEmpty && query.length >= 2)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l10n.homeSearchNoSuggestions,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SuggestionAvatar extends StatelessWidget {
  const _SuggestionAvatar({required this.suggestion});

  final DiscoverySuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final imageUrl = suggestion.imageUrl;
    return CircleAvatar(
      foregroundImage: imageUrl == null || imageUrl.isEmpty
          ? null
          : CachedNetworkImageProvider(imageUrl),
      child: imageUrl == null || imageUrl.isEmpty
          ? Icon(
              switch (suggestion.tab) {
                HomeDiscoveryTab.sessions => AppIcons.sessions,
                HomeDiscoveryTab.venues => AppIcons.venue,
                HomeDiscoveryTab.clubs => AppIcons.clubs,
                HomeDiscoveryTab.tournaments => AppIcons.trophy,
              },
            )
          : null,
    );
  }
}
