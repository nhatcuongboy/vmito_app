import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';

import '../../support/fake_secure_storage.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = options.path == '/users'
        ? '{"success":true,"data":{"data":[{"id":"u1","name":"Linh","email":"l@vmito.com","gender":"FEMALE","level":5}]}}'
        : '{"success":true,"data":{}}';
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

SessionRepositoryImpl _repository(_Adapter adapter) {
  final client = buildApiClient(
    tokenStorage: TokenStorage(FakeSecureStorage()),
    errorBus: ApiErrorBus(),
    onSessionExpired: () async {},
  );
  client.raw.httpClientAdapter = adapter;
  return SessionRepositoryImpl(client);
}

void main() {
  test('searches and parses host player user options', () async {
    final adapter = _Adapter();

    final users = await _repository(adapter).searchUsers(' Linh ');

    expect(adapter.requests.single.path, '/users');
    expect(adapter.requests.single.queryParameters, {'search': 'Linh'});
    expect(users.single.name, 'Linh');
    expect(users.single.level, 5);
  });

  test(
    'posts bulk players as a direct array without players wrapper',
    () async {
      final adapter = _Adapter();
      final payload = [
        {'name': 'Linh', 'gender': 'FEMALE', 'level': 5},
      ];

      await _repository(adapter).createPlayers('s1', payload);

      final request = adapter.requests.single;
      expect(request.path, '/sessions/s1/players/bulk');
      expect(request.method, 'POST');
      expect(request.data, payload);
      expect(request.data, isA<List<dynamic>>());
    },
  );

  test('patches one session player with the normalized edit payload', () async {
    final adapter = _Adapter();
    const payload = {'name': 'Linh', 'level': 5, 'clubId': null};

    await _repository(adapter).updatePlayer('s1', 'p1', payload);

    final request = adapter.requests.single;
    expect(request.path, '/sessions/s1/players/p1');
    expect(request.method, 'PATCH');
    expect(request.data, payload);
  });
}
