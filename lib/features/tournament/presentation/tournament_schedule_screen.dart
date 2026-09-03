import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/features/tournament/application/tournament_schedule_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_schedule_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_schedule_sheets.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

typedef TournamentRefereeOpener =
    void Function(String tournamentId, String matchId);

/// Dormant native port of `/tournament/[id]/schedule`.
///
/// This widget is intentionally not registered with the router yet. Consumers
/// may embed it later and inject the native referee destination independently.
class TournamentScheduleScreen extends ConsumerStatefulWidget {
  const TournamentScheduleScreen({
    required this.idOrSlug,
    this.onOpenReferee,
    super.key,
  });

  final String idOrSlug;
  final TournamentRefereeOpener? onOpenReferee;

  @override
  ConsumerState<TournamentScheduleScreen> createState() =>
      _TournamentScheduleScreenState();
}

class _TournamentScheduleScreenState
    extends ConsumerState<TournamentScheduleScreen> {
  late final FormGroup _searchForm;
  StreamSubscription<Object?>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _searchForm = FormGroup({
      TournamentScheduleFilterControl.query: FormControl<String>(),
    });
    _searchSubscription = _searchForm
        .control(TournamentScheduleFilterControl.query)
        .valueChanges
        .distinct()
        .listen((value) {
          final controller = ref.read(
            tournamentScheduleControllerProvider(widget.idOrSlug).notifier,
          );
          final filters = ref
              .read(tournamentScheduleControllerProvider(widget.idOrSlug))
              .filters;
          controller.setFilters(
            filters.copyWith(query: value as String? ?? ''),
          );
        });
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(
              tournamentScheduleControllerProvider(widget.idOrSlug).notifier,
            )
            .load(),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TournamentScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idOrSlug != widget.idOrSlug) {
      _searchForm.reset();
      unawaited(
        ref
            .read(
              tournamentScheduleControllerProvider(widget.idOrSlug).notifier,
            )
            .load(),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_searchSubscription?.cancel());
    _searchForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      tournamentScheduleControllerProvider(widget.idOrSlug),
    );
    final controller = ref.read(
      tournamentScheduleControllerProvider(widget.idOrSlug).notifier,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tournamentScheduleTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) controller.setPageSize(wide ? 100 : 50);
          });
          if (!state.hasLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.matches.isEmpty) {
            return _ScheduleError(
              message: l10n.tournamentScheduleUnknownError,
              retryLabel: l10n.tournamentScheduleRetry,
              onRetry: () => controller.load(force: true),
            );
          }
          final tournament = state.tournament;
          if (tournament == null) {
            return _ScheduleError(
              message: l10n.tournamentScheduleUnknownError,
              retryLabel: l10n.tournamentScheduleRetry,
              onRetry: () => controller.load(force: true),
            );
          }
          return Column(
            children: [
              _ScheduleToolbar(
                form: _searchForm,
                state: state,
                wide: wide,
                onFilters: () async {
                  final filters = await showTournamentFilterSheet(
                    context,
                    state: state,
                  );
                  if (filters != null) {
                    controller.setFilters(filters);
                    _searchForm
                            .control(
                              TournamentScheduleFilterControl.query,
                            )
                            .value =
                        filters.query;
                  }
                },
                onRefereeOnly: (value) =>
                    controller.setRefereeOnly(value: value),
                onShowPlayers: (value) =>
                    unawaited(controller.setShowPlayerNames(value: value)),
                onViewMode: controller.setViewMode,
                onOverlay: state.canEdit
                    ? () => showTournamentOverlaySheet(
                        context,
                        tournamentId: tournament.id,
                        courts: state.courts,
                      )
                    : null,
              ),
              if (state.courtsError != null ||
                  state.groupsError != null ||
                  state.umpiresError != null)
                _SupportingWarning(
                  text: l10n.tournamentScheduleSupportingWarning,
                ),
              for (final category in tournament.categories)
                if (state.canEdit &&
                    tournamentCategoryReadyForBracket(
                      category,
                      state.matches,
                    ))
                  _BracketBanner(
                    category: category,
                    busy: state.busyCategoryIds.contains(category.id),
                    onFinalize: () => _confirmFinalize(
                      controller,
                      category,
                    ),
                  ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: state.viewMode == TournamentScheduleViewMode.list
                      ? _ScheduleList(
                          state: state,
                          onLoadMore: () =>
                              controller.loadMore(wide ? 100 : 50),
                          onMatch: (match) => _openMatch(
                            state,
                            controller,
                            match,
                            wide,
                          ),
                        )
                      : wide
                      ? _ScheduleGrid(
                          state: state,
                          onMatch: (match) => _openMatch(
                            state,
                            controller,
                            match,
                            wide,
                          ),
                        )
                      : _ScheduleAgenda(
                          state: state,
                          onMatch: (match) => _openMatch(
                            state,
                            controller,
                            match,
                            wide,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openMatch(
    TournamentScheduleState state,
    TournamentScheduleController controller,
    TournamentMatch match,
    bool wide,
  ) async {
    final l10n = AppLocalizations.of(context);
    final tournament = state.tournament!;
    final category = tournament.categories
        .where((item) => item.id == match.categoryId)
        .firstOrNull;
    final assignedReferee =
        state.canEdit ||
        state.ownAssignmentIds.contains(match.id) ||
        match.referee?.userId == state.currentUserId;
    final action = await showTournamentMatchDetails(
      context,
      match: match,
      category: category,
      allMatches: state.matches,
      showPlayerNames: state.showPlayerNames,
      canEdit: state.canEdit,
      canOpenReferee: assignedReferee && widget.onOpenReferee != null,
      wide: wide,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case TournamentMatchAction.editSchedule:
        final draft = await showTournamentScheduleEditSheet(
          context,
          match: match,
          tournament: tournament,
          courts: state.courts,
          umpires: state.umpires,
          wide: wide,
          onSubmit: controller.updateSchedule,
        );
        if (!mounted || draft == null) return;
        _snack(l10n.tournamentScheduleUpdated);
      case TournamentMatchAction.enterResult:
        final draft = await showTournamentResultSheet(
          context,
          match: match,
          category: category,
          sportType: tournament.sportType,
          wide: wide,
          onSubmit: (draft) => controller.saveResult(match.id, draft),
        );
        if (!mounted || draft == null) return;
        _snack(l10n.tournamentScheduleResultSaved);
      case TournamentMatchAction.openReferee:
        widget.onOpenReferee?.call(tournament.id, match.id);
      case TournamentMatchAction.reset:
        if (await _confirm(
          title: l10n.tournamentScheduleResetTitle,
          body: l10n.tournamentScheduleResetBody,
          action: l10n.tournamentScheduleResetAction,
          type: AppConfirmDialogType.destructive,
        )) {
          await _runMutation(
            () => controller.resetResult(match.id),
            l10n.tournamentScheduleResetSuccess,
            l10n.tournamentScheduleResetFailed,
          );
        }
      case TournamentMatchAction.delete:
        if (await _confirm(
          title: l10n.tournamentScheduleDeleteTitle,
          body: l10n.tournamentScheduleDeleteBody,
          action: l10n.commonDelete,
          type: AppConfirmDialogType.destructive,
        )) {
          await _runMutation(
            () => controller.deleteMatch(match.id),
            l10n.tournamentScheduleDeleteSuccess,
            l10n.tournamentScheduleDeleteFailed,
          );
        }
    }
  }

  Future<void> _runMutation(
    Future<void> Function() operation,
    String success,
    String failure,
  ) async {
    try {
      await operation();
      if (mounted) _snack(success);
    } on Object {
      if (mounted) _snack(failure, error: true);
    }
  }

  Future<void> _confirmFinalize(
    TournamentScheduleController controller,
    TournamentCategory category,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
      title: l10n.tournamentScheduleFinalizeTitle,
      body: l10n.tournamentScheduleFinalizeBody,
      action: l10n.tournamentScheduleFinalize,
      type: AppConfirmDialogType.submit,
    )) {
      return;
    }
    await _runMutation(
      () => controller.completeGroupStage(category.id),
      l10n.tournamentScheduleFinalizeSuccess,
      l10n.tournamentScheduleFinalizeFailed,
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    AppConfirmDialogType type = AppConfirmDialogType.submit,
  }) async =>
      await showAppConfirmDialog(
        context,
        type: type,
        title: title,
        content: body,
        confirmLabel: action,
      ) ??
      false;

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({
    required this.form,
    required this.state,
    required this.wide,
    required this.onFilters,
    required this.onRefereeOnly,
    required this.onShowPlayers,
    required this.onViewMode,
    this.onOverlay,
  });

  final FormGroup form;
  final TournamentScheduleState state;
  final bool wide;
  final VoidCallback onFilters;
  final ValueChanged<bool> onRefereeOnly;
  final ValueChanged<bool> onShowPlayers;
  final ValueChanged<TournamentScheduleViewMode> onViewMode;
  final VoidCallback? onOverlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filterCount = state.filters.activeCount;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            AppReactiveForm(
              formGroup: form,
              child: ReactiveTextField<String>(
                formControlName: TournamentScheduleFilterControl.query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.tournamentScheduleSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: state.filters.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.tournamentScheduleClearFilters,
                          onPressed: () => form
                              .control(
                                TournamentScheduleFilterControl.query,
                              )
                              .reset(),
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Badge(
                  isLabelVisible: filterCount > 0,
                  label: Text('$filterCount'),
                  child: OutlinedButton.icon(
                    onPressed: onFilters,
                    icon: const Icon(Icons.tune),
                    label: Text(l10n.tournamentScheduleFilters),
                  ),
                ),
                const Spacer(),
                if (onOverlay != null && wide)
                  IconButton(
                    onPressed: onOverlay,
                    tooltip: l10n.tournamentScheduleOverlay,
                    icon: const Icon(Icons.cast),
                  ),
                SegmentedButton<TournamentScheduleViewMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: TournamentScheduleViewMode.list,
                      icon: const Icon(Icons.view_agenda_outlined),
                      tooltip: l10n.tournamentScheduleList,
                    ),
                    ButtonSegment(
                      value: TournamentScheduleViewMode.calendar,
                      icon: const Icon(Icons.calendar_view_week_outlined),
                      tooltip: l10n.tournamentScheduleCalendar,
                    ),
                  ],
                  selected: {state.viewMode},
                  onSelectionChanged: (value) => onViewMode(value.first),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Switch.adaptive(
                    value: state.showPlayerNames,
                    onChanged: onShowPlayers,
                  ),
                  Text(l10n.tournamentScheduleShowPlayers),
                  if (state.canRefereeAny) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: state.filters.refereeOnly,
                      onSelected: onRefereeOnly,
                      avatar: const Icon(Icons.sports, size: 18),
                      label: Text(l10n.tournamentScheduleRefereeOnly),
                    ),
                  ],
                  if (onOverlay != null && !wide) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onOverlay,
                      icon: const Icon(Icons.cast),
                      label: Text(l10n.tournamentScheduleOverlay),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({
    required this.state,
    required this.onLoadMore,
    required this.onMatch,
  });

  final TournamentScheduleState state;
  final VoidCallback onLoadMore;
  final ValueChanged<TournamentMatch> onMatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = state.filteredMatches;
    if (all.isEmpty) {
      return _EmptySchedule(
        message: state.matches.isEmpty
            ? l10n.tournamentScheduleEmpty
            : l10n.tournamentScheduleNoResults,
      );
    }
    final visible = all.take(state.visibleCount).toList(growable: false);
    final categories = {
      for (final category in state.tournament!.categories)
        category.id: category,
    };
    final grouped = <String, List<TournamentMatch>>{};
    for (final match in visible) {
      grouped.putIfAbsent(match.categoryId, () => []).add(match);
    }
    final rows = <Object>[];
    for (final entry in grouped.entries) {
      rows
        ..add(categories[entry.key] ?? entry.key)
        ..addAll(entry.value);
    }
    if (visible.length < all.length) rows.add(_loadMoreMarker);
    return ListView.builder(
      key: const Key('tournament-schedule-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (identical(row, _loadMoreMarker)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: onLoadMore,
                child: Text(l10n.tournamentScheduleLoadMore),
              ),
            ),
          );
        }
        if (row is TournamentCategory) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              row.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        if (row is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(row, style: Theme.of(context).textTheme.titleMedium),
          );
        }
        final match = row as TournamentMatch;
        final group = state.groups
            .where((item) => item.id == match.groupId)
            .firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TournamentScheduleMatchCard(
            match: match,
            category: categories[match.categoryId],
            group: group,
            allMatches: state.matches,
            showPlayerNames: state.showPlayerNames,
            busy: state.isBusy(match.id),
            onTap: () => onMatch(match),
          ),
        );
      },
    );
  }
}

const _loadMoreMarker = Object();

class _ScheduleAgenda extends StatefulWidget {
  const _ScheduleAgenda({required this.state, required this.onMatch});

  final TournamentScheduleState state;
  final ValueChanged<TournamentMatch> onMatch;

  @override
  State<_ScheduleAgenda> createState() => _ScheduleAgendaState();
}

class _ScheduleAgendaState extends State<_ScheduleAgenda> {
  DateTime? _date;
  String? _courtId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheduled = widget.state.filteredMatches
        .where((match) => match.startTime != null)
        .toList(growable: false);
    final dates = _dates(scheduled);
    final selected = _date ?? dates.firstOrNull;
    final filtered = scheduled
        .where((match) {
          if (selected != null && !_sameDay(match.startTime!, selected)) {
            return false;
          }
          return _courtId == null || match.courtId == _courtId;
        })
        .toList(growable: false);
    return Column(
      key: const Key('tournament-schedule-agenda'),
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final date in dates)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected != null && _sameDay(date, selected),
                    label: Text(
                      DateFormat.MMMEd(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(date),
                    ),
                    onSelected: (_) => setState(() => _date = date),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              ChoiceChip(
                selected: _courtId == null,
                label: Text(l10n.tournamentScheduleAllCourts),
                onSelected: (_) => setState(() => _courtId = null),
              ),
              for (final court in widget.state.courts)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    selected: _courtId == court.id,
                    label: Text(court.label(l10n.tournamentScheduleCourt)),
                    onSelected: (_) => setState(() => _courtId = court.id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _EmptySchedule(message: l10n.tournamentScheduleNoResults)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final match = filtered[index];
                    final category = widget.state.tournament!.categories
                        .where((item) => item.id == match.categoryId)
                        .firstOrNull;
                    final group = widget.state.groups
                        .where((item) => item.id == match.groupId)
                        .firstOrNull;
                    return _AgendaRow(
                      match: match,
                      child: TournamentScheduleMatchCard(
                        match: match,
                        category: category,
                        group: group,
                        allMatches: widget.state.matches,
                        showPlayerNames: widget.state.showPlayerNames,
                        busy: widget.state.isBusy(match.id),
                        onTap: () => widget.onMatch(match),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.match, required this.child});

  final TournamentMatch match;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 54,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            DateFormat.Hm().format(match.startTime!.toLocal()),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
      Expanded(
        child: Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
      ),
    ],
  );
}

class _ScheduleGrid extends StatefulWidget {
  const _ScheduleGrid({required this.state, required this.onMatch});

  final TournamentScheduleState state;
  final ValueChanged<TournamentMatch> onMatch;

  @override
  State<_ScheduleGrid> createState() => _ScheduleGridState();
}

class _ScheduleGridState extends State<_ScheduleGrid> {
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheduled = widget.state.filteredMatches
        .where((match) => match.startTime != null)
        .toList(growable: false);
    final dates = _dates(scheduled);
    final selected = _date ?? dates.firstOrNull;
    if (selected == null) {
      return _EmptySchedule(message: l10n.tournamentScheduleNoResults);
    }
    final dayMatches = scheduled
        .where((match) => _sameDay(match.startTime!, selected))
        .toList(growable: false);
    final courts = widget.state.courts.isNotEmpty
        ? widget.state.courts
        : {
            for (final match in dayMatches)
              if (match.court != null) match.court!.id: match.court!,
          }.values.toList();
    final hours = dayMatches.isEmpty
        ? const <int>[]
        : [
            for (
              var hour = dayMatches
                  .map((match) => match.startTime!.toLocal().hour)
                  .reduce((a, b) => a < b ? a : b);
              hour <=
                  dayMatches
                      .map((match) => match.startTime!.toLocal().hour)
                      .reduce((a, b) => a > b ? a : b);
              hour++
            )
              hour,
          ];
    return Column(
      key: const Key('tournament-schedule-grid'),
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final date in dates)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _sameDay(date, selected),
                    label: Text(
                      DateFormat.yMMMEd(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(date),
                    ),
                    onSelected: (_) => setState(() => _date = date),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: hours.isEmpty || courts.isEmpty
              ? _EmptySchedule(message: l10n.tournamentScheduleNoResults)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 84 + courts.length * 220,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 84),
                              for (final court in courts)
                                SizedBox(
                                  width: 220,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      court.label(l10n.tournamentScheduleCourt),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          for (final hour in hours)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 84,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                      ),
                                    ),
                                  ),
                                  for (final court in courts)
                                    Container(
                                      width: 220,
                                      constraints: const BoxConstraints(
                                        minHeight: 108,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          for (final match in dayMatches.where(
                                            (match) =>
                                                match.courtId == court.id &&
                                                match.startTime!
                                                        .toLocal()
                                                        .hour ==
                                                    hour,
                                          ))
                                            _GridMatch(
                                              match: match,
                                              onTap: () =>
                                                  widget.onMatch(match),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _GridMatch extends StatelessWidget {
  const _GridMatch({required this.match, required this.onTap});

  final TournamentMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat.Hm().format(match.startTime!.toLocal())} · ${match.matchCode ?? '${l10n.tournamentScheduleMatch} ${match.matchNumber}'}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                match.side(1)?.teamLabel ?? l10n.tournamentScheduleTbd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                match.side(2)?.teamLabel ?? l10n.tournamentScheduleTbd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TournamentScheduleMatchCard extends StatelessWidget {
  const TournamentScheduleMatchCard({
    required this.match,
    required this.allMatches,
    required this.showPlayerNames,
    required this.busy,
    required this.onTap,
    this.category,
    this.group,
    super.key,
  });

  final TournamentMatch match;
  final TournamentCategory? category;
  final TournamentCategoryGroup? group;
  final List<TournamentMatch> allMatches;
  final bool showPlayerNames;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = tournamentMatchSideLabel(
      match,
      1,
      allMatches: allMatches,
      toBeDetermined: l10n.tournamentScheduleTbd,
      winnerOfMatch: (number) => '${l10n.tournamentScheduleWinnerOf} $number',
      loserOfMatch: (number) => '${l10n.tournamentScheduleLoserOf} $number',
      showPlayerNames: showPlayerNames,
    );
    final second = tournamentMatchSideLabel(
      match,
      2,
      allMatches: allMatches,
      toBeDetermined: l10n.tournamentScheduleTbd,
      winnerOfMatch: (number) => '${l10n.tournamentScheduleWinnerOf} $number',
      loserOfMatch: (number) => '${l10n.tournamentScheduleLoserOf} $number',
      showPlayerNames: showPlayerNames,
    );
    final winner = match.winnerId;
    return Semantics(
      button: true,
      label:
          '${l10n.tournamentScheduleMatch} ${match.matchNumber}: $first, $second',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${category?.name ?? ''} · ${tournamentRoundLabel(context, match, group: group)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    _StatusPill(match: match),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      match.matchCode ??
                          '${l10n.tournamentScheduleMatch} ${match.matchNumber}',
                    ),
                    Text(
                      match.court?.label(l10n.tournamentScheduleCourt) ??
                          l10n.tournamentScheduleUnscheduled,
                    ),
                    if (match.startTime != null)
                      Text(
                        DateFormat(
                          'dd/MM · HH:mm',
                        ).format(match.startTime!.toLocal()),
                      ),
                    if (_playedDuration(match) case final duration?)
                      Text(
                        '${duration.inMinutes} ${l10n.tournamentScheduleMinutes}',
                      ),
                    if (match.score?.trim().isNotEmpty ?? false)
                      Text(
                        '${l10n.tournamentScheduleScore}: ${match.score}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                const Divider(height: 18),
                _TeamScoreRow(
                  name: first,
                  winner: winner != null && winner == match.side(1)?.id,
                  setScores: [for (final set in match.sets) set.player1Score],
                ),
                const SizedBox(height: 6),
                _TeamScoreRow(
                  name: second,
                  winner: winner != null && winner == match.side(2)?.id,
                  setScores: [for (final set in match.sets) set.player2Score],
                ),
                if (busy) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.name,
    required this.winner,
    required this.setScores,
  });

  final String name;
  final bool winner;
  final List<int> setScores;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (winner) ...[
        Icon(
          Icons.emoji_events,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 6),
      ],
      Expanded(
        child: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: winner ? FontWeight.w700 : null),
        ),
      ),
      for (final score in setScores)
        Container(
          width: 30,
          alignment: Alignment.center,
          child: Text(
            '$score',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.match});

  final TournamentMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = match.isForfeit
        ? (l10n.tournamentScheduleForfeited, Colors.orange)
        : switch (match.status) {
            TournamentMatchStatus.inProgress => (
              l10n.tournamentScheduleInProgress,
              Colors.green,
            ),
            TournamentMatchStatus.finished => (
              l10n.tournamentScheduleFinished,
              Colors.blueGrey,
            ),
            TournamentMatchStatus.cancelled => (
              l10n.tournamentScheduleCancelled,
              Colors.red,
            ),
            TournamentMatchStatus.scheduled => (
              l10n.tournamentScheduleScheduled,
              Colors.blue,
            ),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BracketBanner extends StatelessWidget {
  const _BracketBanner({
    required this.category,
    required this.busy,
    required this.onFinalize,
  });

  final TournamentCategory category;
  final bool busy;
  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.account_tree_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.tournamentScheduleBracketReady} · ${category.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(l10n.tournamentScheduleBracketDescription),
                ],
              ),
            ),
            FilledButton(
              onPressed: busy ? null : onFinalize,
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.tournamentScheduleFinalize),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportingWarning extends StatelessWidget {
  const _SupportingWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy_outlined, size: 46),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ],
  );
}

String tournamentRoundLabel(
  BuildContext context,
  TournamentMatch match, {
  TournamentCategoryGroup? group,
}) {
  final l10n = AppLocalizations.of(context);
  final round = match.round.toUpperCase();
  if (round == 'GROUP') {
    final name = group?.name?.trim();
    if (name?.isNotEmpty ?? false) return name!;
    return group == null || group.number <= 0
        ? l10n.tournamentScheduleGroup
        : '${l10n.tournamentScheduleGroup} ${group.number}';
  }
  if (round == 'FINAL' || round == 'F') return l10n.tournamentScheduleFinal;
  if (round == 'SEMIFINAL' || round == 'SF') {
    return l10n.tournamentScheduleSemifinal;
  }
  if (round == 'QUARTERFINAL' || round == 'QF') {
    return l10n.tournamentScheduleQuarterfinal;
  }
  if (round == 'THIRD_PLACE' || round == '3RD') {
    return l10n.tournamentScheduleThirdPlace;
  }
  final number = RegExp(r'\d+').firstMatch(round)?.group(0);
  return number == null
      ? '${l10n.tournamentScheduleRound} ${match.round}'
      : '${l10n.tournamentScheduleRound} $number';
}

List<DateTime> _dates(Iterable<TournamentMatch> matches) {
  final dates = <DateTime>{
    for (final match in matches)
      if (match.startTime case final time?)
        DateTime(time.toLocal().year, time.toLocal().month, time.toLocal().day),
  }.toList()..sort();
  return dates;
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

Duration? _playedDuration(TournamentMatch match) {
  final start = match.startTime;
  if (start == null || match.status == TournamentMatchStatus.scheduled) {
    return null;
  }
  final end = match.endTime ?? DateTime.now();
  final duration = end.difference(start);
  return duration.isNegative ? null : duration;
}
