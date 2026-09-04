import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_create_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

class TournamentLocationChoice {
  const TournamentLocationChoice({
    required this.query,
    this.name,
    this.details,
  });

  final String query;
  final String? name;
  final TournamentPlaceDetails? details;
}

class TournamentLocationPickerSheet extends ConsumerStatefulWidget {
  const TournamentLocationPickerSheet({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  ConsumerState<TournamentLocationPickerSheet> createState() =>
      _TournamentLocationPickerSheetState();
}

class _TournamentLocationPickerSheetState
    extends ConsumerState<TournamentLocationPickerSheet> {
  late final FormGroup _form;
  StreamSubscription<Object?>? _subscription;
  Timer? _debounce;
  List<TournamentPlaceSuggestion> _suggestions = const [];
  bool _isLoading = false;

  String get _query => (_form.control('query').value as String? ?? '').trim();

  @override
  void initState() {
    super.initState();
    _form = FormGroup({
      'query': FormControl<String>(value: widget.initialQuery),
    });
    _subscription = _form.control('query').valueChanges.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _search);
      setState(() {});
    });
    if (widget.initialQuery.trim().length >= 2) {
      _debounce = Timer(Duration.zero, _search);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
    _form.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query;
    if (query.length < 2) {
      if (mounted) setState(() => _suggestions = const []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(tournamentCreateControllerProvider.notifier)
          .searchPlaces(
            input: query,
            language: Localizations.localeOf(context).languageCode,
          );
      if (mounted && query == _query) setState(() => _suggestions = result);
    } on Object {
      if (mounted) setState(() => _suggestions = const []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _select(TournamentPlaceSuggestion suggestion) async {
    setState(() => _isLoading = true);
    try {
      final details = await ref
          .read(tournamentCreateControllerProvider.notifier)
          .placeDetails(
            placeId: suggestion.placeId,
            language: Localizations.localeOf(context).languageCode,
          );
      if (mounted) {
        Navigator.pop(
          context,
          TournamentLocationChoice(
            query: details.address.isEmpty
                ? suggestion.primaryText
                : details.address,
            name: suggestion.primaryText,
            details: details,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tournamentCreateLocationSearchTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppReactiveForm<void>(
                formGroup: _form,
                child: ReactiveTextField<String>(
                  key: const Key('tournament-location-search'),
                  formControlName: 'query',
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.tournamentCreateLocationHint,
                    prefixIcon: const Icon(AppIcons.search),
                  ),
                ),
              ),
              if (_isLoading) const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  children: [
                    if (_query.isNotEmpty)
                      ListTile(
                        key: const Key('tournament-use-manual-location'),
                        leading: const Icon(AppIcons.addLocation),
                        title: Text(
                          l10n.tournamentCreateUseManualLocation(_query),
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          TournamentLocationChoice(query: _query),
                        ),
                      ),
                    for (final suggestion in _suggestions)
                      ListTile(
                        leading: const Icon(AppIcons.location),
                        title: Text(suggestion.primaryText),
                        subtitle: suggestion.secondaryText.isEmpty
                            ? null
                            : Text(suggestion.secondaryText),
                        onTap: _isLoading ? null : () => _select(suggestion),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
