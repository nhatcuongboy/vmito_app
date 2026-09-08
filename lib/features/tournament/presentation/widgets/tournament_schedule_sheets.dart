import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/features/tournament/application/tournament_schedule_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_schedule_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_app/shared/widgets/app_time_picker.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

enum TournamentMatchAction {
  editSchedule,
  enterResult,
  openReferee,
  reset,
  delete,
}

Future<TournamentScheduleFilters?> showTournamentFilterSheet(
  BuildContext context, {
  required TournamentScheduleState state,
}) => showModalBottomSheet<TournamentScheduleFilters>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: .9,
    child: _TournamentFilterSheet(state: state),
  ),
);

Future<TournamentMatchAction?> showTournamentMatchDetails(
  BuildContext context, {
  required TournamentMatch match,
  required TournamentCategory? category,
  required List<TournamentMatch> allMatches,
  required bool showPlayerNames,
  required bool canEdit,
  required bool canOpenReferee,
  required bool wide,
}) {
  final content = _TournamentMatchDetails(
    match: match,
    category: category,
    allMatches: allMatches,
    showPlayerNames: showPlayerNames,
    canEdit: canEdit,
    canOpenReferee: canOpenReferee,
  );
  if (wide) {
    return showDialog<TournamentMatchAction>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
          child: content,
        ),
      ),
    );
  }
  return showModalBottomSheet<TournamentMatchAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => content,
  );
}

Future<TournamentScheduleUpdateDraft?> showTournamentScheduleEditSheet(
  BuildContext context, {
  required TournamentMatch match,
  required TournamentDetail tournament,
  required List<TournamentCourt> courts,
  required List<TournamentUmpire> umpires,
  required bool wide,
  required Future<void> Function(TournamentScheduleUpdateDraft draft) onSubmit,
}) => _showAdaptive<TournamentScheduleUpdateDraft>(
  context,
  wide: wide,
  child: _TournamentScheduleEditForm(
    match: match,
    tournament: tournament,
    courts: courts,
    umpires: umpires,
    onSubmit: onSubmit,
  ),
);

Future<TournamentResultDraft?> showTournamentResultSheet(
  BuildContext context, {
  required TournamentMatch match,
  required TournamentCategory? category,
  required scoring.SportType sportType,
  required bool wide,
  required Future<void> Function(TournamentResultDraft draft) onSubmit,
}) => _showAdaptive<TournamentResultDraft>(
  context,
  wide: wide,
  child: _TournamentResultForm(
    match: match,
    category: category,
    sportType: sportType,
    onSubmit: onSubmit,
  ),
);

Future<void> showTournamentOverlaySheet(
  BuildContext context, {
  required String tournamentId,
  required List<TournamentCourt> courts,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _TournamentOverlaySheet(
    tournamentId: tournamentId,
    courts: courts,
  ),
);

Future<T?> _showAdaptive<T>(
  BuildContext context, {
  required bool wide,
  required Widget child,
}) {
  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 850),
          child: child,
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(heightFactor: .92, child: child),
  );
}

class _TournamentFilterSheet extends StatefulWidget {
  const _TournamentFilterSheet({required this.state});

  final TournamentScheduleState state;

  @override
  State<_TournamentFilterSheet> createState() => _TournamentFilterSheetState();
}

class _TournamentFilterSheetState extends State<_TournamentFilterSheet> {
  late final FormGroup form;

  @override
  void initState() {
    super.initState();
    form = tournamentScheduleFilterForm(widget.state.filters);
  }

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rounds =
        widget.state.matches
            .map((match) => match.round)
            .where((round) => round.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final registrations = <String, TournamentRegistration>{};
    for (final match in widget.state.matches) {
      for (final participant in match.participants) {
        final registration = participant.registration;
        if (registration != null) registrations[registration.id] = registration;
      }
    }
    return AppReactiveForm<void>(
      formGroup: form,
      child: Column(
        children: [
          _SheetHeader(
            title: l10n.tournamentScheduleFilterTitle,
            onClose: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterSection<String>(
                    title: l10n.tournamentScheduleCategories,
                    controlName: TournamentScheduleFilterControl.categoryIds,
                    values: [
                      for (final item in widget.state.tournament!.categories)
                        item.id,
                    ],
                    label: (id) => widget.state.tournament!.categories
                        .firstWhere((item) => item.id == id)
                        .name,
                  ),
                  _FilterSection<String>(
                    title: l10n.tournamentScheduleRounds,
                    controlName: TournamentScheduleFilterControl.rounds,
                    values: rounds,
                    label: (value) => _roundLabel(l10n, value),
                  ),
                  _FilterSection<String>(
                    title: l10n.tournamentScheduleCourts,
                    controlName: TournamentScheduleFilterControl.courtIds,
                    values: [for (final court in widget.state.courts) court.id],
                    label: (id) => widget.state.courts
                        .firstWhere((court) => court.id == id)
                        .label(l10n.tournamentScheduleCourt),
                  ),
                  _FilterSection<TournamentScheduleStatusFilter>(
                    title: l10n.tournamentScheduleStatuses,
                    controlName: TournamentScheduleFilterControl.statuses,
                    values: TournamentScheduleStatusFilter.values,
                    label: (value) => switch (value) {
                      TournamentScheduleStatusFilter.upcoming =>
                        l10n.tournamentScheduleScheduled,
                      TournamentScheduleStatusFilter.finished =>
                        l10n.tournamentScheduleFinished,
                      TournamentScheduleStatusFilter.cancelled =>
                        l10n.tournamentScheduleCancelled,
                      TournamentScheduleStatusFilter.forfeited =>
                        l10n.tournamentScheduleForfeited,
                    },
                  ),
                  _FilterSection<String>(
                    title: l10n.tournamentScheduleTeams,
                    controlName: TournamentScheduleFilterControl.teamIds,
                    values: registrations.keys.toList(),
                    label: (id) => registrations[id]!.teamLabel,
                  ),
                  Text(
                    l10n.tournamentScheduleDateTime,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ReactiveDateButton(
                        controlName: TournamentScheduleFilterControl.dateFrom,
                        label: l10n.tournamentScheduleFrom,
                        firstDate: widget.state.tournament!.startDate.subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: widget.state.tournament!.endDate.add(
                          const Duration(days: 365),
                        ),
                      ),
                      _ReactiveDateButton(
                        controlName: TournamentScheduleFilterControl.dateTo,
                        label: l10n.tournamentScheduleTo,
                        firstDate: widget.state.tournament!.startDate.subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: widget.state.tournament!.endDate.add(
                          const Duration(days: 365),
                        ),
                      ),
                    ],
                  ),
                  ReactiveValueListenableBuilder<DateTime>(
                    formControlName: TournamentScheduleFilterControl.dateTo,
                    builder: (context, _, _) =>
                        form.hasError(TournamentScheduleValidation.dateRange)
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.tournamentScheduleInvalidRange,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final query = widget.state.filters.query;
                        final cleared = tournamentScheduleFilterForm(
                          TournamentScheduleFilters(query: query),
                        );
                        form.reset(value: cleared.value);
                        cleared.dispose();
                      },
                      child: Text(l10n.tournamentScheduleClearFilters),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        form.markAllAsTouched();
                        if (!form.valid) return;
                        Navigator.pop(
                          context,
                          tournamentFiltersFromForm(
                            form,
                            refereeOnly: widget.state.filters.refereeOnly,
                          ),
                        );
                      },
                      child: Text(l10n.tournamentScheduleApply),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection<T> extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.controlName,
    required this.values,
    required this.label,
  });

  final String title;
  final String controlName;
  final List<T> values;
  final String Function(T value) label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ReactiveValueListenableBuilder<Set<T>>(
          formControlName: controlName,
          builder: (context, control, _) => Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final value in values)
                FilterChip(
                  label: Text(label(value)),
                  selected: control.value?.contains(value) ?? false,
                  onSelected: (_) {
                    final selected = {...?control.value};
                    selected.contains(value)
                        ? selected.remove(value)
                        : selected.add(value);
                    control
                      ..value = selected
                      ..markAsTouched();
                  },
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TournamentMatchDetails extends StatelessWidget {
  const _TournamentMatchDetails({
    required this.match,
    required this.category,
    required this.allMatches,
    required this.showPlayerNames,
    required this.canEdit,
    required this.canOpenReferee,
  });

  final TournamentMatch match;
  final TournamentCategory? category;
  final List<TournamentMatch> allMatches;
  final bool showPlayerNames;
  final bool canEdit;
  final bool canOpenReferee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String side(int position) => tournamentMatchSideLabel(
      match,
      position,
      allMatches: allMatches,
      toBeDetermined: l10n.tournamentScheduleTbd,
      winnerOfMatch: (number) => '${l10n.tournamentScheduleWinnerOf} $number',
      loserOfMatch: (number) => '${l10n.tournamentScheduleLoserOf} $number',
      showPlayerNames: showPlayerNames,
    );
    final format = match.matchFormat ?? category?.matchFormat ?? 'BEST_OF_1';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          title: l10n.tournamentScheduleDetails,
          onClose: () => Navigator.pop(context),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category?.name ?? ''} · ${match.matchCode ?? '${l10n.tournamentScheduleMatch} ${match.matchNumber}'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(_roundLabel(l10n, match.round)),
                const SizedBox(height: 18),
                _DetailTeam(
                  name: side(1),
                  winner: match.winnerId == match.side(1)?.id,
                  scores: [for (final set in match.sets) set.player1Score],
                ),
                const SizedBox(height: 8),
                _DetailTeam(
                  name: side(2),
                  winner: match.winnerId == match.side(2)?.id,
                  scores: [for (final set in match.sets) set.player2Score],
                ),
                const Divider(height: 28),
                _DetailLine(
                  icon: Icons.rule,
                  label: l10n.tournamentScheduleFormat,
                  value: format.replaceAll('_', ' '),
                ),
                if (match.score?.trim().isNotEmpty ?? false)
                  _DetailLine(
                    icon: Icons.scoreboard_outlined,
                    label: l10n.tournamentScheduleScore,
                    value: match.score!,
                  ),
                _DetailLine(
                  icon: Icons.schedule,
                  label: l10n.tournamentScheduleDateTime,
                  value: match.startTime == null
                      ? l10n.tournamentScheduleUnscheduled
                      : DateFormat.yMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).add_Hm().format(match.startTime!.toLocal()),
                ),
                _DetailLine(
                  icon: Icons.stadium_outlined,
                  label: l10n.tournamentScheduleCourt,
                  value:
                      match.court?.label(l10n.tournamentScheduleCourt) ??
                      l10n.tournamentScheduleUnscheduled,
                ),
                _DetailLine(
                  icon: Icons.sports,
                  label: l10n.tournamentScheduleReferee,
                  value:
                      match.referee?.name ??
                      match.refereeName ??
                      l10n.tournamentScheduleTbd,
                ),
                if (match.notes?.trim().isNotEmpty ?? false)
                  _DetailLine(
                    icon: Icons.notes,
                    label: l10n.tournamentScheduleNotes,
                    value: match.notes!,
                  ),
                if (canEdit || canOpenReferee) ...[
                  const Divider(height: 28),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canOpenReferee)
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(
                            context,
                            TournamentMatchAction.openReferee,
                          ),
                          icon: const Icon(Icons.sports_score),
                          label: Text(l10n.tournamentScheduleOpenReferee),
                        ),
                      if (canEdit)
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(
                            context,
                            TournamentMatchAction.editSchedule,
                          ),
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: Text(l10n.tournamentScheduleEdit),
                        ),
                      if (canEdit)
                        OutlinedButton.icon(
                          onPressed: match.participantsResolved
                              ? () => Navigator.pop(
                                  context,
                                  TournamentMatchAction.enterResult,
                                )
                              : null,
                          icon: const Icon(Icons.scoreboard_outlined),
                          label: Text(l10n.tournamentScheduleEnterResult),
                        ),
                      if (canEdit &&
                          match.status == TournamentMatchStatus.finished)
                        TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            TournamentMatchAction.reset,
                          ),
                          child: Text(l10n.tournamentScheduleResetResult),
                        ),
                      if (canEdit)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          onPressed: () => Navigator.pop(
                            context,
                            TournamentMatchAction.delete,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l10n.tournamentScheduleDeleteMatch),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TournamentScheduleEditForm extends StatefulWidget {
  const _TournamentScheduleEditForm({
    required this.match,
    required this.tournament,
    required this.courts,
    required this.umpires,
    required this.onSubmit,
  });

  final TournamentMatch match;
  final TournamentDetail tournament;
  final List<TournamentCourt> courts;
  final List<TournamentUmpire> umpires;
  final Future<void> Function(TournamentScheduleUpdateDraft draft) onSubmit;

  @override
  State<_TournamentScheduleEditForm> createState() =>
      _TournamentScheduleEditFormState();
}

class _TournamentScheduleEditFormState
    extends State<_TournamentScheduleEditForm> {
  late final FormGroup form;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    form = tournamentScheduleEditForm(
      match: widget.match,
      tournamentStartDate: widget.tournament.startDate,
    );
  }

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppReactiveForm<void>(
      formGroup: form,
      child: Column(
        children: [
          _SheetHeader(
            title: l10n.tournamentScheduleEditTitle,
            onClose: submitting ? null : () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ReactiveTextField<String>(
                    formControlName: TournamentScheduleEditControl.matchCode,
                    decoration: InputDecoration(
                      labelText: l10n.tournamentScheduleMatchCode,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ReactiveDateButton(
                          controlName: TournamentScheduleEditControl.date,
                          label: l10n.tournamentScheduleDate,
                          firstDate: widget.tournament.startDate.subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: widget.tournament.endDate.add(
                            const Duration(days: 30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ReactiveTimeButton(
                          controlName: TournamentScheduleEditControl.time,
                          label: l10n.tournamentScheduleStartTime,
                        ),
                      ),
                    ],
                  ),
                  ReactiveValueListenableBuilder<Duration>(
                    formControlName: TournamentScheduleEditControl.time,
                    builder: (context, _, _) =>
                        form.hasError(TournamentScheduleValidation.dateTimePair)
                        ? Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                l10n.tournamentScheduleDateTimePair,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  ReactiveDropdownField<int>(
                    formControlName: TournamentScheduleEditControl.duration,
                    decoration: InputDecoration(
                      labelText: l10n.tournamentScheduleDuration,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final value in tournamentMatchDurations)
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            '$value ${l10n.tournamentScheduleMinutes}',
                            style: const TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ReactiveDropdownField<String>(
                    formControlName: TournamentScheduleEditControl.courtId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.tournamentScheduleCourt,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          l10n.tournamentScheduleUnscheduled,
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ),
                      for (final court in widget.courts)
                        DropdownMenuItem(
                          value: court.id,
                          child: Text(
                            court.label(l10n.tournamentScheduleCourt),
                            style: const TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ReactiveDropdownField<String>(
                    formControlName: TournamentScheduleEditControl.refereeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.tournamentScheduleReferee,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          l10n.tournamentScheduleTbd,
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ),
                      for (final umpire in widget.umpires)
                        DropdownMenuItem(
                          value: umpire.id,
                          child: Text(
                            umpire.name,
                            style: const TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _FormActions(
            submitting: submitting,
            secondaryLabel: l10n.tournamentScheduleClearSchedule,
            onSecondary: () {
              form.control(TournamentScheduleEditControl.date).reset();
              form.control(TournamentScheduleEditControl.time).reset();
              form.control(TournamentScheduleEditControl.courtId).value = '';
              form.markAsTouched();
            },
            onSubmit: () async {
              form
                ..markAllAsTouched()
                ..updateValueAndValidity();
              if (!form.valid || submitting) return;
              setState(() => submitting = true);
              final draft = tournamentScheduleDraftFromForm(
                form,
                matchId: widget.match.id,
              );
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await widget.onSubmit(draft);
                if (mounted) navigator.pop(draft);
              } on Object {
                if (!mounted) return;
                setState(() => submitting = false);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.tournamentScheduleUpdateFailed)),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TournamentResultForm extends StatefulWidget {
  const _TournamentResultForm({
    required this.match,
    required this.category,
    required this.sportType,
    required this.onSubmit,
  });

  final TournamentMatch match;
  final TournamentCategory? category;
  final scoring.SportType sportType;
  final Future<void> Function(TournamentResultDraft draft) onSubmit;

  @override
  State<_TournamentResultForm> createState() => _TournamentResultFormState();
}

class _TournamentResultFormState extends State<_TournamentResultForm> {
  late final scoring.RallyScoringRules rules;
  late final FormGroup form;
  bool submitting = false;

  FormArray<Map<String, Object?>> get sets =>
      form.control(TournamentResultControl.sets)
          as FormArray<Map<String, Object?>>;

  @override
  void initState() {
    super.initState();
    rules = scoring.defaultRules(
      match: widget.match.scoringMatch(widget.category),
      sportType: widget.sportType,
    );
    form = tournamentResultForm(
      match: widget.match,
      rules: rules,
      allowManual: widget.category?.pointsEarning != 'match_results',
    );
  }

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allowManual = widget.category?.pointsEarning != 'match_results';
    return AppReactiveForm<void>(
      formGroup: form,
      child: Column(
        children: [
          _SheetHeader(
            title: l10n.tournamentScheduleResultTitle,
            onClose: submitting ? null : () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ReactiveValueListenableBuilder<TournamentResultMode>(
                    formControlName: TournamentResultControl.mode,
                    builder: (context, control, _) =>
                        SegmentedButton<TournamentResultMode>(
                          segments: [
                            ButtonSegment(
                              value: TournamentResultMode.score,
                              label: Text(l10n.tournamentScheduleScoreBySet),
                            ),
                            ButtonSegment(
                              value: TournamentResultMode.forfeit,
                              label: Text(l10n.tournamentScheduleForfeit),
                            ),
                            if (allowManual)
                              ButtonSegment(
                                value: TournamentResultMode.manual,
                                label: Text(
                                  l10n.tournamentScheduleManualPoints,
                                ),
                              ),
                          ],
                          selected: {
                            control.value ?? TournamentResultMode.score,
                          },
                          onSelectionChanged: (value) {
                            control.value = value.first;
                            form.updateValueAndValidity();
                          },
                        ),
                  ),
                  const SizedBox(height: 18),
                  ReactiveValueListenableBuilder<TournamentResultMode>(
                    formControlName: TournamentResultControl.mode,
                    builder: (context, control, _) =>
                        switch (control.value ?? TournamentResultMode.score) {
                          TournamentResultMode.score => _SetEditor(
                            form: form,
                            rules: rules,
                          ),
                          TournamentResultMode.forfeit => _ForfeitEditor(
                            form: form,
                            match: widget.match,
                          ),
                          TournamentResultMode.manual => _ManualEditor(
                            form: form,
                            match: widget.match,
                          ),
                        },
                  ),
                  ReactiveValueListenableBuilder<TournamentResultMode>(
                    formControlName: TournamentResultControl.mode,
                    builder: (context, _, _) {
                      final error =
                          form.hasError(
                            TournamentScheduleValidation.winnerRequired,
                          )
                          ? l10n.tournamentScheduleWinnerRequired
                          : form.hasError(
                              TournamentScheduleValidation.incompleteResult,
                            )
                          ? l10n.tournamentScheduleIncompleteResult
                          : null;
                      return error == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                error,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            );
                    },
                  ),
                ],
              ),
            ),
          ),
          _FormActions(
            submitting: submitting,
            onSubmit: () async {
              form
                ..markAllAsTouched()
                ..updateValueAndValidity();
              final draft = tournamentResultDraftFromForm(
                form,
                match: widget.match,
                rules: rules,
                isDoubles: (widget.category?.teamSize ?? 1) > 1,
              );
              if (!form.valid || draft == null || submitting) return;
              setState(() => submitting = true);
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await widget.onSubmit(draft);
                if (mounted) navigator.pop(draft);
              } on Object {
                if (!mounted) return;
                setState(() => submitting = false);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.tournamentScheduleResultFailed)),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SetEditor extends StatelessWidget {
  const _SetEditor({required this.form, required this.rules});

  final FormGroup form;
  final scoring.RallyScoringRules rules;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final array =
        form.control(TournamentResultControl.sets)
            as FormArray<Map<String, Object?>>;
    return ReactiveFormArray<Map<String, Object?>>(
      formArrayName: TournamentResultControl.sets,
      builder: (context, _, _) => Column(
        children: [
          Text(
            '${l10n.tournamentScheduleFormat}: Best of ${rules.bestOf} · ${rules.pointsToWin}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          for (final (index, control) in array.controls.indexed)
            AppReactiveForm<void>(
              formGroup: control as FormGroup,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text('${l10n.tournamentScheduleSet} ${index + 1}'),
                    ),
                    Expanded(
                      child: ReactiveTextField<String>(
                        formControlName: TournamentResultControl.set1,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–'),
                    ),
                    Expanded(
                      child: ReactiveTextField<String>(
                        formControlName: TournamentResultControl.set2,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.tournamentScheduleRemoveSet,
                      onPressed: array.controls.length <= 1
                          ? null
                          : () {
                              array.removeAt(index);
                              form.updateValueAndValidity();
                            },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: array.controls.length >= rules.bestOf
                ? null
                : () {
                    array.add(tournamentResultSetForm());
                    form.updateValueAndValidity();
                  },
            icon: const Icon(Icons.add),
            label: Text(l10n.tournamentScheduleAddSet),
          ),
        ],
      ),
    );
  }
}

class _ForfeitEditor extends StatelessWidget {
  const _ForfeitEditor({required this.form, required this.match});

  final FormGroup form;
  final TournamentMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ReactiveDropdownField<int>(
      formControlName: TournamentResultControl.forfeitWinner,
      decoration: InputDecoration(
        labelText: l10n.tournamentScheduleSelectWinner,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(
          value: 1,
          child: Text(
            match.side(1)?.teamLabel ?? l10n.tournamentScheduleTbd,
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
        ),
        DropdownMenuItem(
          value: 2,
          child: Text(
            match.side(2)?.teamLabel ?? l10n.tournamentScheduleTbd,
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
        ),
      ],
      onChanged: (_) => form.updateValueAndValidity(),
    );
  }
}

class _ManualEditor extends StatelessWidget {
  const _ManualEditor({required this.form, required this.match});

  final FormGroup form;
  final TournamentMatch match;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ManualField(
          controlName: TournamentResultControl.manual1,
          label: match.side(1)?.teamLabel ?? '1',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ManualField(
          controlName: TournamentResultControl.manual2,
          label: match.side(2)?.teamLabel ?? '2',
        ),
      ),
    ],
  );
}

class _ManualField extends StatelessWidget {
  const _ManualField({required this.controlName, required this.label});

  final String controlName;
  final String label;

  @override
  Widget build(BuildContext context) => ReactiveTextField<String>(
    formControlName: controlName,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validationMessages: {
      TournamentScheduleValidation.nonNegativeInteger: (_) =>
          AppLocalizations.of(context).tournamentScheduleInvalidNumber,
    },
  );
}

class _TournamentOverlaySheet extends StatelessWidget {
  const _TournamentOverlaySheet({
    required this.tournamentId,
    required this.courts,
  });

  final String tournamentId;
  final List<TournamentCourt> courts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode == 'zh'
        ? 'cn'
        : Localizations.localeOf(context).languageCode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          title: l10n.tournamentScheduleOverlayTitle,
          onClose: () => Navigator.pop(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.tournamentScheduleOverlayDescription),
              const SizedBox(height: 16),
              if (courts.isEmpty)
                Text(l10n.tournamentScheduleNoCourts)
              else
                for (final court in [
                  ...courts,
                ]..sort((a, b) => a.number.compareTo(b.number)))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(court.label(l10n.tournamentScheduleCourt)),
                    subtitle: Text(
                      '${AppConfig.webBaseUrl}/$locale/tournament/$tournamentId/overlay/court/${court.number}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: l10n.tournamentScheduleOverlayCopied,
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '${AppConfig.webBaseUrl}/$locale/tournament/$tournamentId/overlay/court/${court.number}',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.tournamentScheduleOverlayCopied,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReactiveDateButton extends StatelessWidget {
  const _ReactiveDateButton({
    required this.controlName,
    required this.label,
    required this.firstDate,
    required this.lastDate,
  });

  final String controlName;
  final String label;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  Widget build(BuildContext context) => ReactiveDatePicker<DateTime>(
    formControlName: controlName,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, picker, _) => OutlinedButton.icon(
      onPressed: picker.showPicker,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(
        picker.value == null
            ? label
            : DateFormat.yMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(picker.value!),
      ),
    ),
  );
}

class _ReactiveTimeButton extends StatelessWidget {
  const _ReactiveTimeButton({required this.controlName, required this.label});

  final String controlName;
  final String label;

  @override
  Widget build(BuildContext context) =>
      ReactiveValueListenableBuilder<Duration>(
        formControlName: controlName,
        builder: (context, control, _) => OutlinedButton.icon(
          onPressed: () async {
            final value = control.value;
            final selected = await showAppTimePicker(
              context: context,
              initialTime: value == null
                  ? TimeOfDay.now()
                  : TimeOfDay(
                      hour: value.inHours,
                      minute: value.inMinutes.remainder(60),
                    ),
            );
            if (selected != null) {
              control
                ..value = Duration(
                  hours: selected.hour,
                  minutes: selected.minute,
                )
                ..markAsTouched();
            }
          },
          icon: const Icon(Icons.schedule),
          label: Text(
            control.value == null
                ? label
                : TimeOfDay(
                    hour: control.value!.inHours,
                    minute: control.value!.inMinutes.remainder(60),
                  ).format(context),
          ),
        ),
      );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => AppSheetHeader(
    title: title,
    closeButtonEnabled: onClose != null,
    onClose: onClose,
  );
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.submitting,
    required this.onSubmit,
    this.secondaryLabel,
    this.onSecondary,
  });

  final bool submitting;
  final VoidCallback onSubmit;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => AppSheetActionBar(
    child: Row(
      children: [
        if (secondaryLabel != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: submitting ? null : onSecondary,
              child: Text(secondaryLabel!),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context).commonSave),
          ),
        ),
      ],
    ),
  );
}

class _DetailTeam extends StatelessWidget {
  const _DetailTeam({
    required this.name,
    required this.winner,
    required this.scores,
  });

  final String name;
  final bool winner;
  final List<int> scores;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (winner)
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.emoji_events, size: 20),
        ),
      Expanded(
        child: Text(
          name,
          style: TextStyle(fontWeight: winner ? FontWeight.w700 : null),
        ),
      ),
      for (final score in scores)
        SizedBox(
          width: 32,
          child: Text(
            '$score',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _roundLabel(AppLocalizations l10n, String value) {
  final round = value.toUpperCase();
  return switch (round) {
    'GROUP' => l10n.tournamentScheduleGroup,
    'F' || 'FINAL' => l10n.tournamentScheduleFinal,
    'SF' || 'SEMIFINAL' => l10n.tournamentScheduleSemifinal,
    'QF' || 'QUARTERFINAL' => l10n.tournamentScheduleQuarterfinal,
    '3RD' || 'THIRD_PLACE' => l10n.tournamentScheduleThirdPlace,
    _ =>
      '${l10n.tournamentScheduleRound} ${RegExp(r'\d+').firstMatch(round)?.group(0) ?? value}',
  };
}
