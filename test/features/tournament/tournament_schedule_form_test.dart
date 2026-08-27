import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_schedule_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

void main() {
  final match = _match();
  const rules = scoring.RallyScoringRules(
    pointsToWin: 21,
    winBy: 2,
    cap: 30,
    bestOf: 3,
  );

  test('schedule form requires date and time as a pair', () {
    final form = tournamentScheduleEditForm(
      match: match,
      tournamentStartDate: DateTime(2026, 8, 27),
    );
    addTearDown(form.dispose);

    form.control(TournamentScheduleEditControl.date).value = DateTime(
      2026,
      8,
      27,
    );
    form.updateValueAndValidity();
    expect(form.hasError(TournamentScheduleValidation.dateTimePair), isTrue);

    form.control(TournamentScheduleEditControl.time).value = const Duration(
      hours: 9,
      minutes: 30,
    );
    form.updateValueAndValidity();
    expect(form.valid, isTrue);
    final draft = tournamentScheduleDraftFromForm(form, matchId: match.id);
    expect(draft.startTime, DateTime(2026, 8, 27, 9, 30));
    expect(draft.endTime, DateTime(2026, 8, 27, 10, 30));
  });

  test('filter form rejects a reversed date range', () {
    final form = tournamentScheduleFilterForm();
    addTearDown(form.dispose);
    form.control(TournamentScheduleFilterControl.dateFrom).value = DateTime(
      2026,
      8,
      28,
    );
    form.control(TournamentScheduleFilterControl.dateTo).value = DateTime(
      2026,
      8,
      27,
    );
    form.updateValueAndValidity();
    expect(form.hasError(TournamentScheduleValidation.dateRange), isTrue);
  });

  test('score validation honors deuce, cap, and Best-of', () {
    final form = tournamentResultForm(
      match: match,
      rules: rules,
      allowManual: false,
    );
    addTearDown(form.dispose);
    final sets =
        form.control(TournamentResultControl.sets)
            as FormArray<Map<String, Object?>>;
    final first = sets.controls.first as FormGroup;
    first.control(TournamentResultControl.set1).value = '21';
    first.control(TournamentResultControl.set2).value = '19';
    sets.add(tournamentResultSetForm());
    final second = sets.controls[1] as FormGroup;
    second.control(TournamentResultControl.set1).value = '30';
    second.control(TournamentResultControl.set2).value = '29';
    form.updateValueAndValidity();

    final draft = tournamentResultDraftFromForm(
      form,
      match: match,
      rules: rules,
      isDoubles: true,
    );
    expect(form.valid, isTrue);
    expect(draft?.winnerId, 'r1');
    expect(draft?.sets, hasLength(2));
    expect(draft?.player3Score, 51);
  });

  test('incomplete result is blocked and forfeit requires a winner', () {
    final form = tournamentResultForm(
      match: match,
      rules: rules,
      allowManual: false,
    );
    addTearDown(form.dispose);
    expect(
      form.hasError(TournamentScheduleValidation.incompleteResult),
      isTrue,
    );

    form.control(TournamentResultControl.mode).value =
        TournamentResultMode.forfeit;
    form.updateValueAndValidity();
    expect(form.hasError(TournamentScheduleValidation.winnerRequired), isTrue);
    form.control(TournamentResultControl.forfeitWinner).value = 2;
    form.updateValueAndValidity();
    final draft = tournamentResultDraftFromForm(
      form,
      match: match,
      rules: rules,
      isDoubles: false,
    );
    expect(draft?.winnerId, 'r2');
    expect(draft?.isForfeit, isTrue);
  });

  test('manual points support a draw', () {
    final form = tournamentResultForm(
      match: match,
      rules: rules,
      allowManual: true,
    );
    addTearDown(form.dispose);
    form.control(TournamentResultControl.mode).value =
        TournamentResultMode.manual;
    form.control(TournamentResultControl.manual1).value = '5';
    form.control(TournamentResultControl.manual2).value = '5';
    form.updateValueAndValidity();
    final draft = tournamentResultDraftFromForm(
      form,
      match: match,
      rules: rules,
      isDoubles: false,
    );
    expect(draft?.isDraw, isTrue);
    expect(draft?.winnerId, isNull);
  });
}

TournamentMatch _match() => const TournamentMatch(
  id: 'm1',
  categoryId: 'c1',
  round: 'FINAL',
  matchNumber: 1,
  status: TournamentMatchStatus.scheduled,
  matchFormat: 'BEST_OF_3',
  participants: [
    TournamentMatchParticipant(
      position: 1,
      registrationId: 'r1',
      registration: TournamentRegistration(id: 'r1', pairName: 'Team 1'),
    ),
    TournamentMatchParticipant(
      position: 2,
      registrationId: 'r2',
      registration: TournamentRegistration(id: 'r2', pairName: 'Team 2'),
    ),
  ],
);
