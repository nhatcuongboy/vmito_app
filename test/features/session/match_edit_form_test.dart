import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/form/match_edit_form.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';

void main() {
  final match = Match(
    id: 'm1',
    sessionId: 's1',
    courtId: 'c1',
    status: MatchStatus.finished,
    players: [
      for (var index = 0; index < 4; index++)
        MatchPlayer(
          id: 'mp$index',
          playerId: 'p$index',
          position: index,
        ),
    ],
  );

  test('maps vertical court positions into alternating pairs', () {
    final form = matchEditForm(match: match, pair1Score: 21, pair2Score: 18);
    addTearDown(form.dispose);

    final draft = matchUpdateDraftFromForm(
      form,
      playerCount: 4,
      direction: CourtDirection.vertical,
    );

    expect(draft.playerIds, ['p0', 'p1', 'p2', 'p3']);
    expect(draft.pair1PlayerIds, ['p0', 'p2']);
    expect(draft.pair2PlayerIds, ['p1', 'p3']);
    expect(draft.winnerIds, ['p0', 'p2']);
  });

  test('rejects duplicate player selections', () {
    final form = matchEditForm(match: match, pair1Score: 21, pair2Score: 18);
    addTearDown(form.dispose);

    form.control(MatchEditFormControl.player(3)).value = 'p0';
    form.updateValueAndValidity();

    expect(form.hasError('duplicatePlayers'), isTrue);
    expect(form.invalid, isTrue);
  });

  test('requires integer scores but permits fractional shuttlecock counts', () {
    final form = matchEditForm(match: match, pair1Score: 21, pair2Score: 18);
    addTearDown(form.dispose);

    form.control(MatchEditFormControl.pair1Score).value = '2.5';
    form.control(MatchEditFormControl.shuttlecockCount).value = '2.5';
    form.updateValueAndValidity();

    expect(
      form.control(MatchEditFormControl.pair1Score).hasErrors,
      isTrue,
    );
    expect(
      form.control(MatchEditFormControl.shuttlecockCount).valid,
      isTrue,
    );
  });
}
