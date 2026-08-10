import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';

import '../../support/fake_secure_storage.dart';

class _StatisticsAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = switch (options.path) {
      '/sessions/s1/players/statistics' =>
        '{"success":true,"data":{"playerStats":[{"playerId":"p1","playerNumber":1,"totalMatches":2,"regularMatches":2,"extraMatches":0,"wins":1,"losses":1,"winRate":50,"averageScore":0,"scoredMatches":1,"totalPlayTime":20,"totalWaitTime":10,"status":"WAITING"}]}}',
      '/players/p1' =>
        '{"success":true,"data":{"id":"p1","playerNumber":1,"name":"An","status":"WAITING","matchesPlayed":2,"currentWaitTime":5,"totalWaitTime":10}}',
      '/feature-flags' =>
        '{"success":true,"data":{"SHOW_SHUTTLECOCK_COUNT":true}}',
      _ => '{"success":true,"data":{}}',
    };
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
  test('uses statistics, player detail and feature flag endpoints', () async {
    final adapter = _StatisticsAdapter();
    final client = buildApiClient(
      tokenStorage: TokenStorage(FakeSecureStorage()),
      errorBus: ApiErrorBus(),
      onSessionExpired: () async {},
    );
    client.raw.httpClientAdapter = adapter;
    final repository = SessionRepositoryImpl(client);

    final statistics = await repository.playerStatistics('s1');
    final detail = await repository.playerById('p1');
    final showShuttlecocks = await repository.showShuttlecockCount();

    expect(adapter.requests.map((e) => e.path), [
      '/sessions/s1/players/statistics',
      '/players/p1',
      '/feature-flags',
    ]);
    expect(statistics.single.playerId, 'p1');
    expect(detail.name, 'An');
    expect(showShuttlecocks, isTrue);
  });
}
