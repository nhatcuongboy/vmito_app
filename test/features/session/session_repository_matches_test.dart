import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';

import '../../support/fake_secure_storage.dart';

/// `GET /sessions/:id/matches` wraps the list in `{matches, totalMatches,
/// filters}` and — unlike every other match endpoint — parses `score` and
/// `winnerIds` into real JSON instead of leaving them as the raw string
/// column. This reproduces exactly that shape.
class _MatchesAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = jsonEncode({
      'success': true,
      'data': {
        'matches': [
          {
            'id': 'm1',
            'sessionId': 's1',
            'courtId': 'c1',
            'status': 'FINISHED',
            'score': [
              {'playerId': 'p1', 'score': 21},
              {'playerId': 'p2', 'score': 15},
            ],
            'winnerIds': ['p1'],
            'players': [
              {'id': 'mp1', 'playerId': 'p1', 'position': 0},
              {'id': 'mp2', 'playerId': 'p2', 'position': 1},
            ],
          },
        ],
        'totalMatches': 1,
        'filters': {'playerId': null, 'courtId': null},
      },
    });
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('matches unwraps the {matches, totalMatches} envelope and '
      're-encodes parsed score/winnerIds back to JSON strings', () async {
    final adapter = _MatchesAdapter();
    final client = buildApiClient(
      tokenStorage: TokenStorage(FakeSecureStorage()),
      errorBus: ApiErrorBus(),
      onSessionExpired: () async {},
    );
    client.raw.httpClientAdapter = adapter;
    final repository = SessionRepositoryImpl(client);

    final matches = await repository.matches('s1');

    expect(adapter.requests.single.path, '/sessions/s1/matches');
    expect(matches, hasLength(1));
    final match = matches.single;
    expect(match.id, 'm1');
    expect(
      match.score,
      jsonEncode([
        {'playerId': 'p1', 'score': 21},
        {'playerId': 'p2', 'score': 15},
      ]),
    );
    expect(match.winnerIds, jsonEncode(['p1']));
  });
}
