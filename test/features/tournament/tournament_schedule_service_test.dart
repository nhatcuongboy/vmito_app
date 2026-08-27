import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';

class _ApiClient extends Mock implements ApiClient {}

void main() {
  late _ApiClient client;
  late TournamentService service;

  setUp(() {
    client = _ApiClient();
    service = TournamentService(client);
  });

  test('loads matches and supporting schedule collections', () async {
    when(() => client.get<dynamic>('/tournaments/t1/all-matches')).thenAnswer(
      (_) async => _response('/tournaments/t1/all-matches', [_matchJson()]),
    );
    when(() => client.get<dynamic>('/tournaments/t1/courts')).thenAnswer(
      (_) async => _response('/tournaments/t1/courts', [
        {'id': 'court-1', 'courtNumber': 1},
      ]),
    );
    when(() => client.get<dynamic>('/categories/c1/groups')).thenAnswer(
      (_) async => _response('/categories/c1/groups', [
        {'id': 'g1', 'categoryId': 'c1', 'groupNumber': 1},
      ]),
    );
    when(() => client.get<dynamic>('/tournaments/t1/umpires')).thenAnswer(
      (_) async => _response('/tournaments/t1/umpires', [
        {'id': 'u1', 'name': 'Referee'},
      ]),
    );
    when(
      () => client.get<dynamic>(
        '/category-matches/my-assignments',
        queryParameters: {'tournamentId': 't1'},
      ),
    ).thenAnswer(
      (_) async =>
          _response('/category-matches/my-assignments', [_matchJson()]),
    );

    expect(await service.matches('t1'), hasLength(1));
    expect((await service.courts('t1')).single.number, 1);
    expect((await service.categoryGroups('c1')).single.id, 'g1');
    expect((await service.umpires('t1')).single.name, 'Referee');
    expect((await service.ownAssignments('t1')).single.id, 'm1');
  });

  test('sends exact schedule and referee mutation payloads', () async {
    final start = DateTime.utc(2026, 8, 27, 2, 30);
    final end = DateTime.utc(2026, 8, 27, 3, 30);
    when(
      () => client.put<dynamic>(
        '/category-matches/m1',
        data: {'matchCode': 'A-1'},
      ),
    ).thenAnswer((_) async => _response('/category-matches/m1', null));
    when(
      () => client.put<dynamic>(
        '/category-matches/bulk-schedule',
        data: {
          'updates': [
            {
              'matchId': 'm1',
              'courtId': 'court-1',
              'startTime': start.toIso8601String(),
              'endTime': end.toIso8601String(),
            },
          ],
        },
      ),
    ).thenAnswer(
      (_) async => _response('/category-matches/bulk-schedule', null),
    );
    when(
      () => client.patch<dynamic>(
        '/category-matches/m1/referee',
        data: {'refereeId': 'u1'},
      ),
    ).thenAnswer(
      (_) async => _response('/category-matches/m1/referee', _matchJson()),
    );
    when(
      () => client.delete<dynamic>('/category-matches/m1/referee'),
    ).thenAnswer(
      (_) async => _response('/category-matches/m1/referee', _matchJson()),
    );

    await service.updateMatchCode('m1', 'A-1');
    await service.updateMatchSchedule(
      TournamentScheduleUpdateDraft(
        matchId: 'm1',
        matchCode: 'A-1',
        courtId: 'court-1',
        startTime: start,
        endTime: end,
      ),
    );
    await service.assignReferee('m1', 'u1');
    await service.unassignReferee('m1');

    verify(
      () => client.put<dynamic>(
        '/category-matches/bulk-schedule',
        data: any(named: 'data'),
      ),
    ).called(1);
  });

  test('sends result, reset, delete, and finalize mutations', () async {
    when(
      () => client.post<dynamic>(
        '/category-matches/m1/end',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _response('/category-matches/m1/end', _matchJson()),
    );
    when(
      () => client.post<dynamic>('/category-matches/m1/reset-result'),
    ).thenAnswer(
      (_) async => _response('/category-matches/m1/reset-result', _matchJson()),
    );
    when(() => client.delete<dynamic>('/category-matches/m1')).thenAnswer(
      (_) async => _response('/category-matches/m1', null),
    );
    when(
      () => client.post<dynamic>('/categories/c1/complete-group-stage'),
    ).thenAnswer(
      (_) async => _response('/categories/c1/complete-group-stage', null),
    );

    await service.saveResult(
      'm1',
      const TournamentResultDraft(
        score: '21-10',
        winnerId: 'r1',
        player1Score: 21,
        player2Score: 10,
      ),
    );
    await service.resetResult('m1');
    await service.deleteMatch('m1');
    await service.completeGroupStage('c1');

    final resultPayload =
        verify(
              () => client.post<dynamic>(
                '/category-matches/m1/end',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(resultPayload['winnerId'], 'r1');
    verify(
      () => client.post<dynamic>('/category-matches/m1/reset-result'),
    ).called(1);
    verify(() => client.delete<dynamic>('/category-matches/m1')).called(1);
    verify(
      () => client.post<dynamic>('/categories/c1/complete-group-stage'),
    ).called(1);
  });
}

Response<dynamic> _response(String path, Object? data) => Response<dynamic>(
  requestOptions: RequestOptions(path: path),
  data: {'success': true, 'data': data},
);

Map<String, dynamic> _matchJson() => {
  'id': 'm1',
  'categoryId': 'c1',
  'round': 'GROUP',
  'matchNumber': 1,
  'status': 'SCHEDULED',
  'participants': <Object>[],
};
