import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

import '../../support/fake_secure_storage.dart';

/// Serves canned responses without a socket, and counts what was asked for.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.delay = Duration.zero});

  final int statusCode;
  final Duration delay;
  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.toString());
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return ResponseBody.fromString(
      '{"success":true,"data":{"ok":true}}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_RecordingAdapter adapter) {
  final client = buildApiClient(
    tokenStorage: TokenStorage(FakeSecureStorage()),
    errorBus: ApiErrorBus(),
    onSessionExpired: () async {},
  );
  client.raw.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('GET de-duplication', () {
    test('a deduplicated GET completes', () async {
      final adapter = _RecordingAdapter();

      // Regression: the in-flight entry was cleared with
      // `whenComplete(() => _inFlightGets.remove(key))`. `Map.remove` returns
      // the removed value — the future itself — and `whenComplete` awaits any
      // Future its callback returns, so the future waited on itself and every
      // deduplicated GET hung forever. Since dedup is the default, that was
      // every read in the app.
      final response =
          await _client(
                adapter,
              )
              .get<Map<String, dynamic>>('/sessions')
              .timeout(const Duration(seconds: 5));

      expect(response.statusCode, 200);
    });

    test('concurrent identical GETs share one request', () async {
      final adapter = _RecordingAdapter(
        delay: const Duration(milliseconds: 50),
      );
      final client = _client(adapter);

      await Future.wait([
        client.get<Map<String, dynamic>>('/sessions'),
        client.get<Map<String, dynamic>>('/sessions'),
        client.get<Map<String, dynamic>>('/sessions'),
      ]).timeout(const Duration(seconds: 5));

      expect(adapter.requests, hasLength(1));
    });

    test('the entry is released, so a later GET refetches', () async {
      final adapter = _RecordingAdapter();
      final client = _client(adapter);

      // A stale entry would make post-mutation reads return old data.
      await client.get<Map<String, dynamic>>('/sessions');
      await client.get<Map<String, dynamic>>('/sessions');

      expect(adapter.requests, hasLength(2));
    });

    test('different params are not collapsed together', () async {
      final adapter = _RecordingAdapter(
        delay: const Duration(milliseconds: 50),
      );
      final client = _client(adapter);

      await Future.wait([
        client.get<Map<String, dynamic>>(
          '/sessions',
          queryParameters: {'page': 1},
        ),
        client.get<Map<String, dynamic>>(
          '/sessions',
          queryParameters: {'page': 2},
        ),
      ]);

      expect(adapter.requests, hasLength(2));
    });

    test('param order does not affect the key', () async {
      final adapter = _RecordingAdapter(
        delay: const Duration(milliseconds: 50),
      );
      final client = _client(adapter);

      // The web app keys on `JSON.stringify(params)`, which depends on
      // insertion order, so these two miss each other and fire twice.
      await Future.wait([
        client.get<Map<String, dynamic>>(
          '/sessions',
          queryParameters: {'a': 1, 'b': 2},
        ),
        client.get<Map<String, dynamic>>(
          '/sessions',
          queryParameters: {'b': 2, 'a': 1},
        ),
      ]);

      expect(adapter.requests, hasLength(1));
    });

    test('dedup: false always issues its own request', () async {
      final adapter = _RecordingAdapter(
        delay: const Duration(milliseconds: 50),
      );
      final client = _client(adapter);

      await Future.wait([
        client.get<Map<String, dynamic>>('/sessions', dedup: false),
        client.get<Map<String, dynamic>>('/sessions', dedup: false),
      ]);

      expect(adapter.requests, hasLength(2));
    });
  });

  group('error surfacing', () {
    test('callers see ApiException, never DioException', () async {
      final client = _client(_RecordingAdapter(statusCode: 500));

      await expectLater(
        client.get<Map<String, dynamic>>('/sessions'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
    });

    test('a failed GET releases its in-flight entry', () async {
      final client = _client(_RecordingAdapter(statusCode: 500));

      // Without release, one failure would poison that URL for the session.
      for (var i = 0; i < 2; i++) {
        await expectLater(
          client.get<Map<String, dynamic>>('/sessions'),
          throwsA(isA<ApiException>()),
        );
      }
    });
  });
}
