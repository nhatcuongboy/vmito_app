import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';

class _ApiClient extends Mock implements ApiClient {}

void main() {
  late _ApiClient client;
  late TournamentManagementService service;

  setUp(() {
    client = _ApiClient();
    service = TournamentManagementService(client);
  });

  test(
    'loads access and manager collections without GET deduplication',
    () async {
      when(
        () => client.get<dynamic>('/tournaments/t1/my-access', dedup: false),
      ).thenAnswer(
        (_) async => _response('/tournaments/t1/my-access', {
          'tournamentId': 't1',
          'isHost': false,
          'isAdmin': false,
          'permissions': ['RESULTS'],
        }),
      );
      when(
        () => client.get<dynamic>('/tournaments/t1/managers', dedup: false),
      ).thenAnswer(
        (_) async => _response('/tournaments/t1/managers', [
          {
            'id': 'm1',
            'tournamentId': 't1',
            'userId': 'u1',
            'permissions': ['SCHEDULE'],
          },
        ]),
      );

      expect((await service.access('t1')).permissions, {
        TournamentPermission.results,
      });
      expect((await service.managers('t1')).single.userId, 'u1');
    },
  );

  test('sends exact manager and duplicate payload shapes', () async {
    when(
      () => client.post<dynamic>(
        '/tournaments/t1/managers',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _response('/tournaments/t1/managers', {
        'id': 'm1',
        'tournamentId': 't1',
        'userId': 'u1',
        'permissions': ['RESULTS', 'SCHEDULE'],
      }),
    );
    when(
      () => client.post<dynamic>(
        '/tournaments/t1/duplicate',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _response('/tournaments/t1/duplicate', _tournamentJson()),
    );

    await service.addManager('t1', 'u1', {
      TournamentPermission.results,
      TournamentPermission.schedule,
    });
    await service.duplicateTournament(
      't1',
      DuplicateTournamentDraft(
        name: 'Copy',
        startDate: DateTime.utc(2026, 10),
        endDate: DateTime.utc(2026, 10, 2),
        venueId: 'v1',
        copySchedule: true,
        copyMatchResults: true,
      ),
    );

    final managerPayload =
        verify(
              () => client.post<dynamic>(
                '/tournaments/t1/managers',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(managerPayload['userId'], 'u1');
    expect(managerPayload['permissions'], ['RESULTS', 'SCHEDULE']);

    final duplicatePayload =
        verify(
              () => client.post<dynamic>(
                '/tournaments/t1/duplicate',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(duplicatePayload['venueId'], 'v1');
    expect(duplicatePayload['copy'], {
      'format': true,
      'schedule': true,
      'teams': false,
      'matchResults': true,
      'venues': false,
      'customHomePage': false,
    });
  });

  test('maps account images and venue search result envelopes', () async {
    when(
      () => client.get<dynamic>(
        '/user-images',
        queryParameters: const {
          'category': 'SESSION_COVER',
          'page': 1,
          'limit': 100,
        },
        dedup: false,
      ),
    ).thenAnswer(
      (_) async => _response('/user-images', {
        'data': [
          {'id': 'i1', 'url': 'https://image', 'publicId': 'public-1'},
        ],
      }),
    );
    when(
      () => client.get<dynamic>(
        '/venues/search',
        queryParameters: {
          'page': 1,
          'limit': 100,
          'closureStatus': 'OPERATING',
          'keyword': 'arena',
          'sortBy': 'relevance',
        },
        dedup: false,
      ),
    ).thenAnswer(
      (_) async => _response('/venues/search', {
        'data': [
          {'id': 'v1', 'name': 'Arena'},
        ],
      }),
    );

    expect((await service.images()).single.publicId, 'public-1');
    expect((await service.searchVenues('arena')).single.name, 'Arena');
  });
}

Response<dynamic> _response(String path, Object? data) => Response<dynamic>(
  requestOptions: RequestOptions(path: path),
  data: {'success': true, 'data': data},
);

Map<String, dynamic> _tournamentJson() => {
  'id': 't2',
  'slug': 'copy',
  'name': 'Copy',
  'startDate': '2026-10-01T00:00:00Z',
  'endDate': '2026-10-02T00:00:00Z',
  'hostId': 'host-1',
  'status': 'PREPARING',
  'isPublished': false,
};
