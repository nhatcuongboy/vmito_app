import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

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

  test('browse sends the active discovery filters and sort', () async {
    final client = _ApiClient();
    const query = {
      'publishedOnly': true,
      'status': 'PREPARING,IN_PROGRESS',
      'sportType': 'PICKLEBALL',
      'favoriteOnly': true,
      'sortBy': 'name',
      'sortOrder': 'desc',
      'keyword': 'open',
      'city': 'Hà Nội',
    };
    when(
      () => client.get<Map<String, dynamic>>(
        '/tournaments',
        queryParameters: query,
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/tournaments'),
        data: const {'success': true, 'data': <dynamic>[]},
      ),
    );

    await TournamentService(client).browse(
      search: 'open',
      city: 'Hà Nội',
      statuses: const {
        TournamentStatus.preparing,
        TournamentStatus.inProgress,
      },
      sportTypes: const {'PICKLEBALL'},
      favoriteOnly: true,
      sortBy: 'name',
      sortOrder: 'desc',
    );

    verify(
      () => client.get<Map<String, dynamic>>(
        '/tournaments',
        queryParameters: query,
      ),
    ).called(1);
  });
}
