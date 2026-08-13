import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/form/session_form_defaults.dart';
import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/form/session_reactive_form.dart';
import 'package:vmito_app/features/session/domain/session.dart';

void main() {
  test('reactive form round-trips typed values and dynamic courts', () {
    final base = SessionFormDefaults.create(hostName: 'Cường');
    final form = createSessionReactiveForm(base);
    addTearDown(form.dispose);

    form
      ..control(SessionFormControl.name).value = 'Kèo pickleball'
      ..control(SessionFormControl.sportType).value =
          SessionSportType.pickleball
      ..control(SessionFormControl.locationKind).value =
          SessionLocationKind.custom
      ..control(SessionFormControl.customLocationName).value = 'Sân A';
    final courts = form.control(SessionFormControl.courts) as dynamic;
    courts.add(
      sessionCourtForm(
        SessionCourtDraft(key: nextDraftKey(), courtNumber: 2),
      ),
    );

    final state = form.toSessionFormState(base: base);
    expect(state.name, 'Kèo pickleball');
    expect(state.sportType, SessionSportType.pickleball);
    expect(state.locationKind, SessionLocationKind.custom);
    expect(state.courts.map((court) => court.courtNumber), [1, 2]);
  });

  test('clone defaults preserve sport and remove court identities', () {
    const session = Session(
      id: 's1',
      name: 'Pickleball',
      status: SessionStatus.preparing,
      sportType: SessionSportType.pickleball,
      courts: [],
      numberOfCourts: 2,
    );

    final state = SessionFormDefaults.fromSession(session, isClone: true);
    expect(state.sportType, SessionSportType.pickleball);
    expect(state.isEditMode, isFalse);
    expect(state.courts, hasLength(2));
    expect(state.courts.every((court) => court.courtId == null), isTrue);
  });
}
