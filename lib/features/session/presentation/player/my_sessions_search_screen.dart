import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_search_history.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_search_suggestions.dart';
import 'package:vmito_app/features/session/domain/form/my_sessions_search_form.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class MySessionsSearchScreen extends ConsumerStatefulWidget {
  const MySessionsSearchScreen({
    required this.scope,
    this.initialQuery = '',
    super.key,
  });

  final MySessionScope scope;
  final String initialQuery;

  @override
  ConsumerState<MySessionsSearchScreen> createState() =>
      _MySessionsSearchScreenState();
}

class _MySessionsSearchScreenState
    extends ConsumerState<MySessionsSearchScreen> {
  late final FormGroup _form;
  late final StreamSubscription<Object?> _querySubscription;
  final _focusNode = FocusNode();
  Timer? _debounce;
  AsyncValue<List<Session>> _suggestions = const AsyncData([]);
  var _requestGeneration = 0;
  var _showQueryError = false;

  FormControl<String> get _queryControl =>
      _form.control(MySessionsSearchControl.query) as FormControl<String>;

  String get _query =>
      normalizeMySessionsSearchQuery(_queryControl.value ?? '');

  @override
  void initState() {
    super.initState();
    _form = createMySessionsSearchForm(initialQuery: widget.initialQuery);
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
            .read(mySessionsSearchSuggestionServiceProvider)
            .search(scope: widget.scope, query: query);
        if (!mounted || generation != _requestGeneration) return;
        setState(() => _suggestions = AsyncData(suggestions));
      } on Object catch (error, stackTrace) {
        if (!mounted || generation != _requestGeneration) return;
        setState(() => _suggestions = AsyncError(error, stackTrace));
      }
    });
  }

  Future<void> _submit([String? value]) async {
    final query = normalizeMySessionsSearchQuery(value ?? _query);
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
    await ref
        .read(mySessionsSearchHistoryProvider.notifier)
        .add(widget.scope, query);
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
        ref.watch(mySessionsSearchHistoryProvider)[widget.scope] ?? const [];
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
            key: const Key('my-sessions-search-field'),
            formControlName: MySessionsSearchControl.query,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => unawaited(_submit()),
            showErrors: (_) => false,
            validationMessages: {
              ValidationMessage.required: (_) => l10n.homeSearchRequired,
            },
            decoration: InputDecoration(
              hintText: l10n.mySessionsSearchHint,
              prefixIcon: const Icon(AppIcons.search),
              suffixIcon: _queryControl.value?.isNotEmpty ?? false
                  ? IconButton(
                      key: const Key('my-sessions-search-clear-query'),
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
                      .read(mySessionsSearchHistoryProvider.notifier)
                      .remove(widget.scope, query),
                ),
                onClear: history.isEmpty
                    ? null
                    : () => unawaited(
                        ref
                            .read(mySessionsSearchHistoryProvider.notifier)
                            .clear(widget.scope),
                      ),
              )
            : _SuggestionView(
                query: _query,
                suggestions: _suggestions,
                onSubmit: () => unawaited(_submit()),
                onSuggestion: (session) => unawaited(
                  context.push(AppRoutes.sessionDetail(session.id)),
                ),
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
  final AsyncValue<List<Session>> suggestions;
  final VoidCallback onSubmit;
  final ValueChanged<Session> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      children: [
        ListTile(
          key: const Key('my-sessions-search-submit-suggestion'),
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
            for (final session in items)
              ListTile(
                key: ValueKey('my-sessions-search-suggestion-${session.id}'),
                leading: _SuggestionAvatar(session: session),
                title: Text(session.name),
                subtitle: _subtitleWidget(session),
                onTap: () => onSuggestion(session),
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

  String? _subtitle(Session session) {
    final subtitle = session.venue?.name ?? session.location;
    return subtitle?.trim().isNotEmpty ?? false ? subtitle : null;
  }

  Widget? _subtitleWidget(Session session) {
    final subtitle = _subtitle(session);
    return subtitle == null
        ? null
        : Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
  }
}

class _SuggestionAvatar extends StatelessWidget {
  const _SuggestionAvatar({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final imageUrl = session.coverPhoto;
    return CircleAvatar(
      foregroundImage: imageUrl == null || imageUrl.isEmpty
          ? null
          : CachedNetworkImageProvider(imageUrl),
      child: imageUrl == null || imageUrl.isEmpty
          ? const Icon(AppIcons.sessions)
          : null,
    );
  }
}
