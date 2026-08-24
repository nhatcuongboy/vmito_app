import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';

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
    final body = options.method == 'DELETE'
        ? '{"success":true,"data":{"deleted":1}}'
        : '{"success":true,"data":{"data":[],"total":0,"page":2,"limit":20,"totalPages":2}}';
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

RegistrationRepository _repository(_RecordingAdapter adapter) {
  final client = buildApiClient(
    tokenStorage: TokenStorage(FakeSecureStorage()),
    errorBus: ApiErrorBus(),
    onSessionExpired: () async {},
  );
  client.raw.httpClientAdapter = adapter;
  return RegistrationRepository(client);
}

void main() {
  test(
    'uses outgoing join-request endpoints and pagination contract',
    () async {
      final adapter = _RecordingAdapter();
      final repository = _repository(adapter);

      final page = await repository.myJoinRequests(page: 2, limit: 20);
      await repository.withdrawMyJoinRequest('session-9');

      expect(page.page, 2);
      expect(adapter.requests[0].path, '/players/me/join-requests');
      expect(adapter.requests[0].queryParameters, {'page': 2, 'limit': 20});
      expect(
        adapter.requests[1].path,
        '/players/me/join-requests/session-9',
      );
      expect(adapter.requests[1].method, 'DELETE');
    },
  );
}
