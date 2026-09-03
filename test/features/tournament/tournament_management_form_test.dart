import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_management_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

void main() {
  final tournament = TournamentDetail(
    id: 't1',
    slug: 'vmito-open',
    name: 'Vmito Open',
    startDate: DateTime.utc(2026, 9, 10),
    endDate: DateTime.utc(2026, 9, 12),
    hostId: 'host-1',
    status: TournamentStatus.preparing,
    isPublished: false,
    categories: const [],
    venues: const [],
    playerCount: 0,
    pairCount: 0,
  );

  test('date form rejects an end date before start', () {
    final form = tournamentDatesForm(tournament);
    addTearDown(form.dispose);

    form.control(TournamentSettingsControl.endDate).value = DateTime(2026, 9);

    expect(
      form.hasError(TournamentManagementValidation.endBeforeStart),
      isTrue,
    );
  });

  test('YouTube form accepts supported hosts and rejects unrelated URLs', () {
    final form = tournamentVideosForm(tournament);
    addTearDown(form.dispose);
    final control =
        (form.control(TournamentSettingsControl.videos) as FormArray<String>)
            .controls[0];

    _setValue(control, 'https://youtu.be/abc');
    expect(control.valid, isTrue);
    _setValue(control, 'https://example.com/watch?v=abc');
    expect(
      control.hasError(TournamentManagementValidation.invalidYoutubeUrl),
      isTrue,
    );
  });

  test('delete confirmation requires the exact trimmed tournament name', () {
    final form = tournamentDeleteForm(tournament);
    addTearDown(form.dispose);
    final control = form.control(TournamentSettingsControl.confirmName);

    _setValue(control, 'Other');
    control.markAsTouched();
    expect(
      control.hasError(TournamentManagementValidation.tournamentNameMismatch),
      isTrue,
    );
    _setValue(control, '  Vmito Open  ');
    expect(control.valid, isTrue);
  });

  test('duplicate form enforces result dependency and maps payload', () {
    final form = tournamentDuplicateForm(tournament);
    addTearDown(form.dispose);

    form
      ..control(TournamentDuplicateControl.copySchedule).value = false
      ..control(TournamentDuplicateControl.copyResults).value = true;
    expect(
      form.hasError(
        TournamentManagementValidation.resultRequiresSchedule,
      ),
      isTrue,
    );

    form
      ..control(TournamentDuplicateControl.copySchedule).value = true
      ..control(TournamentDuplicateControl.venueId).value = 'venue-1';
    final draft = duplicateDraftFromForm(form);
    expect(draft.venueId, 'venue-1');
    expect(draft.toJson()['copy'], {
      'format': true,
      'schedule': true,
      'teams': true,
      'matchResults': true,
      'venues': true,
      'customHomePage': true,
    });
  });

  test('manager form requires at least one permission', () {
    final form = tournamentManagerForm(userId: 'u1');
    addTearDown(form.dispose);
    expect(
      form.hasError(TournamentManagementValidation.permissionsRequired),
      isTrue,
    );

    form
            .control(
              TournamentManagerControl.permission(
                TournamentPermission.schedule,
              ),
            )
            .value =
        true;
    expect(form.valid, isTrue);
    expect(tournamentManagerPermissions(form), {
      TournamentPermission.schedule,
    });
  });
}

void _setValue(AbstractControl<dynamic> control, Object? value) {
  control.value = value;
}
