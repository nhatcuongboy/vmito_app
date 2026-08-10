import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';

import '../../support/fake_secure_storage.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = options.path.endsWith('/count')
        ? '{"success":true,"data":{"count":4}}'
        : '{"success":true,"data":{"data":[],"total":0,"page":1,"limit":20,"totalPages":1}}';
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

SessionRepositoryImpl _repository(_RecordingAdapter adapter) {
  final client = buildApiClient(
    tokenStorage: TokenStorage(FakeSecureStorage()),
    errorBus: ApiErrorBus(),
    onSessionExpired: () async {},
  );
  client.raw.httpClientAdapter = adapter;
  return SessionRepositoryImpl(client);
}

void main() {
  test(
    'hosted and joined share search/status/pagination query contract',
    () async {
      final adapter = _RecordingAdapter();
      final repository = _repository(adapter);
      const query = SessionListQuery(
        page: 2,
        search: '  sân A  ',
        excludedStatuses: [SessionStatus.finished, SessionStatus.cancelled],
      );

      await repository.hostedBy('u1', limit: 20, page: 2, query: query);
      await repository.joinedByCurrentUser(query);

      expect(adapter.requests[0].path, '/sessions');
      expect(adapter.requests[0].queryParameters, {
        'hostId': 'u1',
        'page': 2,
        'limit': 20,
        'sortBy': 'startTime',
        'sortOrder': 'desc',
        'searchQuery': 'sân A',
        'excludeStatuses': 'FINISHED,CANCELLED',
      });
      expect(adapter.requests[1].path, '/players/me/sessions');
      expect(
        adapter.requests[1].queryParameters.containsKey('hostId'),
        isFalse,
      );
      expect(
        adapter.requests[1].queryParameters['excludeStatuses'],
        'FINISHED,CANCELLED',
      );
    },
  );

  test('pending list and count use the dedicated player endpoints', () async {
    final adapter = _RecordingAdapter();
    final repository = _repository(adapter);

    await repository.pendingJoinRequests(page: 3, limit: 20, search: 'An');
    final count = await repository.pendingJoinRequestCount();

    expect(adapter.requests[0].path, '/players/pending-requests');
    expect(adapter.requests[0].queryParameters, {
      'page': 3,
      'limit': 20,
      'searchQuery': 'An',
    });
    expect(adapter.requests[1].path, '/players/pending-requests/count');
    expect(count, 4);
  });
}
