import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';

class _ApiClient extends Mock implements ApiClient {}

void main() {
  test('loads detail by slug from the public tournament endpoint', () async {
    final client = _ApiClient();
    when(() => client.get<dynamic>('/tournaments/vmito-open')).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/tournaments/vmito-open'),
        data: {
          'success': true,
          'data': {
            'id': 't1',
            'slug': 'vmito-open',
            'name': 'Vmito Open',
            'startDate': '2026-08-25T00:00:00Z',
            'endDate': '2026-08-26T00:00:00Z',
            'hostId': 'host-1',
            'status': 'FINISHED',
            'isPublished': true,
          },
        },
      ),
    );

    final tournament = await TournamentService(client).detail('vmito-open');

    expect(tournament.id, 't1');
    verify(() => client.get<dynamic>('/tournaments/vmito-open')).called(1);
  });

  test('sorts sponsors using the backend display order', () async {
    final client = _ApiClient();
    when(() => client.get<dynamic>('/tournaments/t1/sponsors')).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/tournaments/t1/sponsors'),
        data: {
          'success': true,
          'data': [
            {'id': 's2', 'name': 'Second', 'displayOrder': 2},
            {'id': 's1', 'name': 'First', 'displayOrder': 1},
          ],
        },
      ),
    );

    final sponsors = await TournamentService(client).sponsors('t1');

    expect(sponsors.map((sponsor) => sponsor.id), ['s1', 's2']);
  });
}
