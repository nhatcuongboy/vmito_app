import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/tournament/data/tournament_player_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_sponsor_service.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';

class _Api extends Mock implements ApiClient {}

Response<dynamic> _response(dynamic data) => Response<dynamic>(
  requestOptions: RequestOptions(),
  data: {'success': true, 'data': data},
);

void main() {
  late _Api api;
  setUp(() => api = _Api());
  test('player resource routes and envelopes match web API', () async {
    final service = TournamentPlayerService(api);
    when(
      () => api.get<dynamic>('/tournaments/t/players', dedup: false),
    ).thenAnswer(
      (_) async => _response([
        {'id': 'p', 'name': 'An'},
      ]),
    );
    when(
      () => api.get<dynamic>('/tournament-players/p/matches', dedup: false),
    ).thenAnswer((_) async => _response(<dynamic>[]));
    when(
      () =>
          api.post<dynamic>('/tournaments/t/players', data: any(named: 'data')),
    ).thenAnswer((_) async => _response({'id': 'p', 'name': 'An'}));
    when(
      () => api.put<dynamic>('/tournament-players/p', data: any(named: 'data')),
    ).thenAnswer((_) async => _response({'id': 'p', 'name': 'An'}));
    when(
      () => api.delete<dynamic>('/tournament-players/p'),
    ).thenAnswer((_) async => _response(null));
    expect((await service.list('t')).single.id, 'p');
    expect(await service.matches('p'), isEmpty);
    await service.save('t', const PlayerDraft(name: 'An', userId: 'u'));
    verify(
      () => api.post<dynamic>(
        '/tournaments/t/players',
        data: {'name': 'An', 'userId': 'u'},
      ),
    ).called(1);
    await service.save('t', const PlayerDraft(name: 'An'), id: 'p');
    final payload =
        verify(
              () => api.put<dynamic>(
                '/tournament-players/p',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map;
    expect(payload.containsKey('userId'), isTrue);
    expect(payload['userId'], isNull);
    expect(payload.containsKey('imagePublicId'), isTrue);
    await service.delete('p');
    verify(() => api.delete<dynamic>('/tournament-players/p')).called(1);
  });

  test(
    'bulk import is one atomic request with original line numbers',
    () async {
      final service = TournamentPlayerService(api);
      when(
        () => api.post<dynamic>(
          '/tournaments/t/players/bulk-create',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _response({
          'count': 1,
          'players': [
            {'id': 'p', 'name': 'An'},
          ],
        }),
      );
      final rows = parsePlayerImport('\n,An,Nam,0123', []);
      expect((await service.bulkCreate('t', rows)).single.name, 'An');
      verify(
        () => api.post<dynamic>(
          '/tournaments/t/players/bulk-create',
          data: {
            'rows': [
              {
                'lineNumber': 2,
                'name': 'An',
                'gender': 'MALE',
                'phone': '0123',
              },
            ],
          },
        ),
      ).called(1);
      await expectLater(service.bulkCreate('t', []), throwsArgumentError);
      await expectLater(
        service.bulkCreate('t', parsePlayerImport('A,,bad', [])),
        throwsArgumentError,
      );
    },
  );

  test('sponsor CRUD sends logo public ID and explicit clears', () async {
    final service = TournamentSponsorService(api);
    when(
      () => api.get<dynamic>('/tournaments/t/sponsors', dedup: false),
    ).thenAnswer(
      (_) async => _response([
        {'id': 's', 'name': 'Brand', 'logoPublicId': 'asset'},
      ]),
    );
    when(
      () => api.post<dynamic>(
        '/tournaments/t/sponsors',
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _response({'id': 's', 'name': 'Brand'}));
    when(
      () => api.put<dynamic>('/sponsors/s', data: any(named: 'data')),
    ).thenAnswer((_) async => _response({'id': 's', 'name': 'Brand'}));
    when(
      () => api.delete<dynamic>('/sponsors/s'),
    ).thenAnswer((_) async => _response(null));
    expect((await service.list('t')).single.logoPublicId, 'asset');
    await service.save(
      't',
      const SponsorDraft(
        name: 'Brand',
        logo: 'https://a.com/a.png',
        logoPublicId: 'asset',
        displayOrder: 3,
      ),
    );
    verify(
      () => api.post<dynamic>(
        '/tournaments/t/sponsors',
        data: {
          'name': 'Brand',
          'logo': 'https://a.com/a.png',
          'logoPublicId': 'asset',
          'displayOrder': 3,
        },
      ),
    ).called(1);
    await service.save('t', const SponsorDraft(name: 'Brand'), id: 's');
    verify(
      () => api.put<dynamic>(
        '/sponsors/s',
        data: {
          'name': 'Brand',
          'website': null,
          'logo': null,
          'logoPublicId': null,
          'displayOrder': 0,
        },
      ),
    ).called(1);
    await service.delete('s');
    verify(() => api.delete<dynamic>('/sponsors/s')).called(1);
  });
}
