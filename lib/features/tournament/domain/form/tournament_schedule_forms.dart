import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

abstract final class TournamentScheduleFilterControl {
  static const query = 'query';
  static const categoryIds = 'categoryIds';
  static const rounds = 'rounds';
  static const courtIds = 'courtIds';
  static const statuses = 'statuses';
  static const teamIds = 'teamIds';
  static const dateFrom = 'dateFrom';
  static const dateTo = 'dateTo';
}

abstract final class TournamentScheduleEditControl {
  static const matchCode = 'matchCode';
  static const date = 'date';
  static const time = 'time';
  static const duration = 'duration';
  static const courtId = 'courtId';
  static const refereeId = 'refereeId';
}

abstract final class TournamentResultControl {
  static const mode = 'mode';
  static const sets = 'sets';
  static const forfeitWinner = 'forfeitWinner';
  static const manual1 = 'manual1';
  static const manual2 = 'manual2';
  static const set1 = 'player1Score';
  static const set2 = 'player2Score';
}

abstract final class TournamentScheduleValidation {
  static const dateRange = 'dateRange';
  static const dateTimePair = 'dateTimePair';
  static const incompleteResult = 'incompleteResult';
  static const winnerRequired = 'winnerRequired';
  static const nonNegativeInteger = 'nonNegativeInteger';
}

enum TournamentResultMode { score, forfeit, manual }

FormGroup tournamentScheduleFilterForm([
  TournamentScheduleFilters filters = const TournamentScheduleFilters(),
]) => FormGroup(
  {
    TournamentScheduleFilterControl.query: FormControl<String>(
      value: filters.query,
    ),
    TournamentScheduleFilterControl.categoryIds: FormControl<Set<String>>(
      value: {...filters.categoryIds},
    ),
    TournamentScheduleFilterControl.rounds: FormControl<Set<String>>(
      value: {...filters.rounds},
    ),
    TournamentScheduleFilterControl.courtIds: FormControl<Set<String>>(
      value: {...filters.courtIds},
    ),
    TournamentScheduleFilterControl.statuses:
        FormControl<Set<TournamentScheduleStatusFilter>>(
          value: {...filters.statuses},
        ),
    TournamentScheduleFilterControl.teamIds: FormControl<Set<String>>(
      value: {...filters.teamIds},
    ),
    TournamentScheduleFilterControl.dateFrom: FormControl<DateTime>(
      value: filters.dateFrom,
    ),
    TournamentScheduleFilterControl.dateTo: FormControl<DateTime>(
      value: filters.dateTo,
    ),
  },
  validators: [Validators.delegate(_validDateRange)],
);

TournamentScheduleFilters tournamentFiltersFromForm(
  FormGroup form, {
  required bool refereeOnly,
}) => TournamentScheduleFilters(
  query: _value<String>(form, TournamentScheduleFilterControl.query) ?? '',
  categoryIds:
      _value<Set<String>>(
        form,
        TournamentScheduleFilterControl.categoryIds,
      ) ??
      const {},
  rounds:
      _value<Set<String>>(form, TournamentScheduleFilterControl.rounds) ??
      const {},
  courtIds:
      _value<Set<String>>(form, TournamentScheduleFilterControl.courtIds) ??
      const {},
  statuses:
      _value<Set<TournamentScheduleStatusFilter>>(
        form,
        TournamentScheduleFilterControl.statuses,
      ) ??
      const {},
  teamIds:
      _value<Set<String>>(form, TournamentScheduleFilterControl.teamIds) ??
      const {},
  dateFrom: _value<DateTime>(form, TournamentScheduleFilterControl.dateFrom),
  dateTo: _value<DateTime>(form, TournamentScheduleFilterControl.dateTo),
  refereeOnly: refereeOnly,
);

FormGroup tournamentScheduleEditForm({
  required TournamentMatch match,
  required DateTime tournamentStartDate,
}) {
  final start = match.startTime?.toLocal();
  final scheduledEnd = (match.estimatedEndTime ?? match.endTime)?.toLocal();
  final duration = start != null && scheduledEnd != null
      ? scheduledEnd.difference(start).inMinutes
      : 60;
  return FormGroup(
    {
      TournamentScheduleEditControl.matchCode: FormControl<String>(
        value: match.matchCode ?? '',
      ),
      TournamentScheduleEditControl.date: FormControl<DateTime>(
        value: start == null
            ? null
            : DateTime(start.year, start.month, start.day),
      ),
      TournamentScheduleEditControl.time: FormControl<Duration>(
        value: start == null
            ? null
            : Duration(hours: start.hour, minutes: start.minute),
      ),
      TournamentScheduleEditControl.duration: FormControl<int>(
        value: tournamentMatchDurations.contains(duration) ? duration : 60,
      ),
      TournamentScheduleEditControl.courtId: FormControl<String>(
        value: match.courtId,
      ),
      TournamentScheduleEditControl.refereeId: FormControl<String>(
        value: match.refereeId,
      ),
    },
    validators: [Validators.delegate(_validDateTimePair)],
  );
}

const tournamentMatchDurations = <int>[
  5,
  10,
  15,
  20,
  25,
  30,
  35,
  40,
  45,
  50,
  55,
  60,
  75,
  90,
  105,
  120,
];

TournamentScheduleUpdateDraft tournamentScheduleDraftFromForm(
  FormGroup form, {
  required String matchId,
}) {
  final date = _value<DateTime>(form, TournamentScheduleEditControl.date);
  final time = _value<Duration>(form, TournamentScheduleEditControl.time);
  final duration =
      _value<int>(form, TournamentScheduleEditControl.duration) ?? 60;
  final start = date == null || time == null
      ? null
      : DateTime(
          date.year,
          date.month,
          date.day,
          time.inHours,
          time.inMinutes.remainder(60),
        );
  return TournamentScheduleUpdateDraft(
    matchId: matchId,
    matchCode:
        _value<String>(form, TournamentScheduleEditControl.matchCode)?.trim() ??
        '',
    courtId: _emptyToNull(
      _value<String>(form, TournamentScheduleEditControl.courtId),
    ),
    startTime: start,
    endTime: start?.add(Duration(minutes: duration)),
    refereeId: _emptyToNull(
      _value<String>(form, TournamentScheduleEditControl.refereeId),
    ),
  );
}

FormGroup tournamentResultForm({
  required TournamentMatch match,
  required scoring.RallyScoringRules rules,
  required bool allowManual,
}) {
  final existingSets = match.sets.isEmpty
      ? [const TournamentMatchSet(player1Score: 0, player2Score: 0)]
      : match.sets;
  final winnerPosition = match.winnerId == match.side(1)?.id
      ? 1
      : match.winnerId == match.side(2)?.id
      ? 2
      : null;
  final initialMode = match.isForfeit
      ? TournamentResultMode.forfeit
      : match.player1Points != null || match.player2Points != null
      ? TournamentResultMode.manual
      : allowManual
      ? TournamentResultMode.manual
      : TournamentResultMode.score;
  return FormGroup(
    {
      TournamentResultControl.mode: FormControl<TournamentResultMode>(
        value: initialMode,
      ),
      TournamentResultControl.sets: FormArray<Map<String, Object?>>([
        for (final set in existingSets)
          _resultSetForm(set.player1Score, set.player2Score),
      ]),
      TournamentResultControl.forfeitWinner: FormControl<int>(
        value: winnerPosition,
      ),
      TournamentResultControl.manual1: FormControl<String>(
        value: match.player1Points?.toString() ?? '',
        validators: [Validators.delegate(_nonNegativeInteger)],
      ),
      TournamentResultControl.manual2: FormControl<String>(
        value: match.player2Points?.toString() ?? '',
        validators: [Validators.delegate(_nonNegativeInteger)],
      ),
    },
    validators: [Validators.delegate(_validResult(rules))],
  );
}

FormGroup tournamentResultSetForm() => _resultSetForm(0, 0);

TournamentResultDraft? tournamentResultDraftFromForm(
  FormGroup form, {
  required TournamentMatch match,
  required scoring.RallyScoringRules rules,
  required bool isDoubles,
}) {
  final mode = _value<TournamentResultMode>(form, TournamentResultControl.mode);
  final firstId = match.side(1)?.id;
  final secondId = match.side(2)?.id;
  if (mode == TournamentResultMode.forfeit) {
    final winner = _value<int>(form, TournamentResultControl.forfeitWinner);
    if (winner == null) return null;
    return TournamentResultDraft(
      score: 'W/O',
      winnerId: winner == 1 ? firstId : secondId,
      isForfeit: true,
      includeSets: true,
      player1Score: 0,
      player2Score: 0,
    );
  }
  if (mode == TournamentResultMode.manual) {
    final first = _integer(
      _value<String>(form, TournamentResultControl.manual1),
    );
    final second = _integer(
      _value<String>(form, TournamentResultControl.manual2),
    );
    return TournamentResultDraft(
      score: '$first - $second',
      winnerId: first == second
          ? null
          : first > second
          ? firstId
          : secondId,
      isDraw: first == second,
      player1Points: first,
      player2Points: second,
    );
  }

  final sets = _playedSets(form);
  final outcome = scoring.isMatchComplete(
    [for (final set in sets) set.scoringSet],
    rules,
  );
  if (!outcome.complete || outcome.winnerSide == null) return null;
  final total1 = sets.fold(0, (sum, set) => sum + set.player1Score);
  final total2 = sets.fold(0, (sum, set) => sum + set.player2Score);
  return TournamentResultDraft(
    score: scoring.buildScoreString([
      for (final set in sets) set.scoringSet,
    ]),
    sets: sets,
    includeSets: true,
    winnerId: outcome.winnerSide == 1 ? firstId : secondId,
    player1Score: total1,
    player2Score: total2,
    player3Score: isDoubles ? total1 : null,
    player4Score: isDoubles ? total2 : null,
  );
}

FormGroup _resultSetForm(int first, int second) => FormGroup({
  TournamentResultControl.set1: FormControl<String>(
    value: first == 0 ? '' : first.toString(),
    validators: [Validators.delegate(_nonNegativeInteger)],
  ),
  TournamentResultControl.set2: FormControl<String>(
    value: second == 0 ? '' : second.toString(),
    validators: [Validators.delegate(_nonNegativeInteger)],
  ),
});

ValidatorFunction _validResult(scoring.RallyScoringRules rules) => (control) {
  if (control is! FormGroup) return null;
  final mode = _value<TournamentResultMode>(
    control,
    TournamentResultControl.mode,
  );
  if (mode == TournamentResultMode.forfeit &&
      _value<int>(control, TournamentResultControl.forfeitWinner) == null) {
    return {TournamentScheduleValidation.winnerRequired: true};
  }
  if (mode != TournamentResultMode.score) return null;
  final sets = _playedSets(control);
  if (sets.any((set) => !_validCompletedSet(set, rules))) {
    return {TournamentScheduleValidation.incompleteResult: true};
  }
  final outcome = scoring.isMatchComplete(
    [for (final set in sets) set.scoringSet],
    rules,
  );
  return outcome.complete
      ? null
      : {TournamentScheduleValidation.incompleteResult: true};
};

List<TournamentMatchSet> _sets(FormGroup form) {
  final array =
      form.control(TournamentResultControl.sets)
          as FormArray<Map<String, Object?>>;
  return [
    for (final (index, item) in array.controls.indexed)
      TournamentMatchSet(
        setNumber: index + 1,
        player1Score: _integer(
          (item as FormGroup).control(TournamentResultControl.set1).value
              as String?,
        ),
        player2Score: _integer(
          item.control(TournamentResultControl.set2).value as String?,
        ),
      ),
  ];
}

List<TournamentMatchSet> _playedSets(FormGroup form) => [
  for (final (index, set) in _sets(form).indexed)
    if (index == 0 || set.player1Score > 0 || set.player2Score > 0) set,
];

bool _validCompletedSet(
  TournamentMatchSet set,
  scoring.RallyScoringRules rules,
) {
  final first = set.player1Score;
  final second = set.player2Score;
  if (rules.cap case final cap? when first > cap || second > cap) return false;
  final high = first > second ? first : second;
  final low = first > second ? second : first;
  if (high > rules.pointsToWin) {
    final deuceThreshold = rules.pointsToWin - (rules.winBy - 1);
    if (rules.winBy < 2 || low < deuceThreshold || high - low > rules.winBy) {
      return false;
    }
  }
  return scoring.isSetComplete(first, second, rules).complete;
}

Map<String, dynamic>? _validDateRange(AbstractControl<dynamic> control) {
  if (control is! FormGroup) return null;
  final from = _value<DateTime>(
    control,
    TournamentScheduleFilterControl.dateFrom,
  );
  final to = _value<DateTime>(control, TournamentScheduleFilterControl.dateTo);
  return from != null && to != null && to.isBefore(from)
      ? {TournamentScheduleValidation.dateRange: true}
      : null;
}

Map<String, dynamic>? _validDateTimePair(AbstractControl<dynamic> control) {
  if (control is! FormGroup) return null;
  final date = _value<DateTime>(control, TournamentScheduleEditControl.date);
  final time = _value<Duration>(control, TournamentScheduleEditControl.time);
  return (date == null) != (time == null)
      ? {TournamentScheduleValidation.dateTimePair: true}
      : null;
}

Map<String, dynamic>? _nonNegativeInteger(AbstractControl<dynamic> control) {
  final text = (control.value as String? ?? '').trim();
  if (text.isEmpty) return null;
  final value = int.tryParse(text);
  return value == null || value < 0
      ? {TournamentScheduleValidation.nonNegativeInteger: true}
      : null;
}

T? _value<T>(FormGroup form, String name) => form.control(name).value as T?;

int _integer(String? value) => int.tryParse(value?.trim() ?? '') ?? 0;

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
