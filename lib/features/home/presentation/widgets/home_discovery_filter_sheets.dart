import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentDiscoveryFilters {
  const TournamentDiscoveryFilters({
    this.statuses = const {TournamentStatus.preparing},
    this.sportTypes = const {},
    this.favoriteOnly = false,
  });

  final Set<TournamentStatus> statuses;
  final Set<String> sportTypes;
  final bool favoriteOnly;
}

abstract final class _DiscoveryFilterControl {
  static const favorite = 'favorite';
  static const statuses = 'statuses';
  static const sports = 'sports';
}

class TournamentDiscoveryFilterSheet extends StatefulWidget {
  const TournamentDiscoveryFilterSheet({required this.initial, super.key});

  final TournamentDiscoveryFilters initial;

  @override
  State<TournamentDiscoveryFilterSheet> createState() =>
      _TournamentDiscoveryFilterSheetState();
}

class _TournamentDiscoveryFilterSheetState
    extends State<TournamentDiscoveryFilterSheet> {
  late final FormGroup _form = FormGroup({
    _DiscoveryFilterControl.statuses: FormControl<Set<TournamentStatus>>(
      value: {...widget.initial.statuses},
    ),
    _DiscoveryFilterControl.sports: FormControl<Set<String>>(
      value: {...widget.initial.sportTypes},
    ),
    _DiscoveryFilterControl.favorite: FormControl<bool>(
      value: widget.initial.favoriteOnly,
    ),
  });

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _toggle<T>(String name, T value) {
    final control = _form.control(name) as FormControl<Set<T>>;
    final next = {...?control.value};
    next.contains(value) ? next.remove(value) : next.add(value);
    control.value = next;
  }

  void _submit() {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    Navigator.of(context).pop(
      TournamentDiscoveryFilters(
        statuses:
            _form.control(_DiscoveryFilterControl.statuses).value
                as Set<TournamentStatus>? ??
            const {},
        sportTypes:
            _form.control(_DiscoveryFilterControl.sports).value
                as Set<String>? ??
            const {},
        favoriteOnly:
            _form.control(_DiscoveryFilterControl.favorite).value as bool? ??
            false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FilterSheetFrame(
      title: l10n.homeDiscoveryTournamentFilters,
      onReset: () => Navigator.of(
        context,
      ).pop(const TournamentDiscoveryFilters()),
      onApply: _submit,
      child: AppReactiveForm(
        formGroup: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeDiscoveryStatus,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ReactiveValueListenableBuilder<Set<TournamentStatus>>(
              formControlName: _DiscoveryFilterControl.statuses,
              builder: (context, control, _) => Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final status in TournamentStatus.values)
                    FilterChip(
                      key: ValueKey(
                        'tournament-discovery-status-${status.name}',
                      ),
                      label: Text(_statusLabel(l10n, status)),
                      selected: control.value?.contains(status) ?? false,
                      onSelected: (_) => _toggle(
                        _DiscoveryFilterControl.statuses,
                        status,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.homeDiscoverySport,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ReactiveValueListenableBuilder<Set<String>>(
              formControlName: _DiscoveryFilterControl.sports,
              builder: (context, control, _) => Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final sport in const ['BADMINTON', 'PICKLEBALL'])
                    FilterChip(
                      key: ValueKey('tournament-discovery-sport-$sport'),
                      label: Text(
                        sport == 'BADMINTON'
                            ? l10n.sessionSportBadminton
                            : l10n.sessionSportPickleball,
                      ),
                      selected: control.value?.contains(sport) ?? false,
                      onSelected: (_) =>
                          _toggle(_DiscoveryFilterControl.sports, sport),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ReactiveSwitchListTile(
              key: const Key('tournament-discovery-filter-favorite'),
              formControlName: _DiscoveryFilterControl.favorite,
              title: Text(l10n.homeDiscoveryFavoriteOnly),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, TournamentStatus status) =>
      switch (status) {
        TournamentStatus.preparing => l10n.tournamentStatusPreparing,
        TournamentStatus.inProgress => l10n.tournamentStatusInProgress,
        TournamentStatus.finished => l10n.tournamentStatusFinished,
        TournamentStatus.cancelled => l10n.tournamentStatusCancelled,
      };
}

class _FilterSheetFrame extends StatelessWidget {
  const _FilterSheetFrame({
    required this.title,
    required this.child,
    required this.onReset,
    required this.onApply,
  });

  final String title;
  final Widget child;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('home-discovery-filter-reset'),
                    onPressed: onReset,
                    child: Text(
                      AppLocalizations.of(context).sessionFiltersReset,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('home-discovery-filter-apply'),
                    onPressed: onApply,
                    child: Text(
                      AppLocalizations.of(context).sessionFiltersApply,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
