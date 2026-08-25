import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/form/match_update_draft.dart';

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
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': null}),
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
  late _RecordingAdapter adapter;
  late SessionRepositoryImpl repository;

  setUp(() {
    adapter = _RecordingAdapter();
    final client = buildApiClient(
      tokenStorage: TokenStorage(FakeSecureStorage()),
      errorBus: ApiErrorBus(),
      onSessionExpired: () async {},
    );
    client.raw.httpClientAdapter = adapter;
    repository = SessionRepositoryImpl(client);
  });

  test('updateMatch patches the typed payload', () async {
    const draft = MatchUpdateDraft(
      playerIds: ['p1', 'p2'],
      pair1PlayerIds: ['p1'],
      pair2PlayerIds: ['p2'],
      noResult: false,
      pair1Score: 21,
      pair2Score: 9,
      isExtra: false,
      notes: 'note',
    );

    await repository.updateMatch('m1', draft);

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/matches/m1');
    expect(request.data, draft.toRequestBody());
  });

  test('deleteMatch deletes the match endpoint', () async {
    await repository.deleteMatch('m1');

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/matches/m1');
  });
}
