import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';

import '../../support/fake_secure_storage.dart';

class _VenueAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"success":true,"data":[{"id":"v1","type":"CREATE","status":"PENDING","payload":{"name":"Rainbow"},"createdAt":"2026-08-29T08:00:00Z","submittedBy":{"id":"u1","name":"An"}}]}',
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
  test('loads pending admin venue requests using the web endpoint', () async {
    final adapter = _VenueAdapter();
    final client = buildApiClient(
      tokenStorage: TokenStorage(FakeSecureStorage()),
      errorBus: ApiErrorBus(),
      onSessionExpired: () async {},
    );
    client.raw.httpClientAdapter = adapter;

    final requests = await VenueService(client).pendingAdminRequests();

    expect(adapter.request?.path, '/venue-requests/admin');
    expect(adapter.request?.queryParameters, {'status': 'PENDING'});
    expect(requests.single.displayName, 'Rainbow');
    expect(requests.single.submittedBy?.name, 'An');
  });
}
