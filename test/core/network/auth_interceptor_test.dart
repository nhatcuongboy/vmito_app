import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

import '../../support/fake_secure_storage.dart';

/// Every request 401s except `/auth/refresh`, whose outcome is configurable —
/// the shape needed to drive `AuthInterceptor`'s refresh-then-retry path.
class _RefreshScenarioAdapter implements HttpClientAdapter {
  _RefreshScenarioAdapter(this.refreshOutcome);

  final _RefreshOutcome refreshOutcome;
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/refresh')) {
      refreshCalls++;
      switch (refreshOutcome) {
        case _RefreshOutcome.succeeds:
          return ResponseBody.fromString(
            '{"success":true,"data":{"accessToken":"new-access"}}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        case _RefreshOutcome.rejected:
          return ResponseBody.fromString(
            '{"success":false,"error":{"message":"invalid refresh token"}}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        case _RefreshOutcome.networkFailure:
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'no network',
          );
      }
    }

    // Every non-refresh request looks like an expired access token.
    return ResponseBody.fromString(
      '{"success":false,"error":{"message":"unauthorized"}}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

enum _RefreshOutcome { succeeds, rejected, networkFailure }

class _Fixture {
  _Fixture(_RefreshOutcome outcome)
    : tokens = TokenStorage(
        FakeSecureStorage({
          'vmito.access_token': 'stale-access',
          'vmito.refresh_token': 'valid-refresh',
        }),
      ),
      adapter = _RefreshScenarioAdapter(outcome);

  final TokenStorage tokens;
  final _RefreshScenarioAdapter adapter;
  bool sessionExpired = false;
  late final ApiClient client;

  Future<void> ready() async {
    await tokens.hydrate();
    client = buildApiClient(
      tokenStorage: tokens,
      errorBus: ApiErrorBus(),
      onSessionExpired: () async {
        sessionExpired = true;
      },
      httpClientAdapter: adapter,
    );
  }
}

void main() {
  group('AuthInterceptor refresh-on-401', () {
    test(
      'a successful refresh retries the request with the new token',
      () async {
        final fixture = _Fixture(_RefreshOutcome.succeeds);
        await fixture.ready();

        await expectLater(
          fixture.client.get<Map<String, dynamic>>('/sessions'),
          throwsA(isA<ApiException>()),
        );

        // The retried request still 401s in this fixture (every non-refresh
        // path does), but the refresh itself must have run exactly once and
        // must not have ended the session.
        expect(fixture.adapter.refreshCalls, 1);
        expect(fixture.sessionExpired, isFalse);
        expect(await fixture.tokens.readRefreshToken(), 'valid-refresh');
      },
    );

    test('the server rejecting the refresh token ends the session', () async {
      final fixture = _Fixture(_RefreshOutcome.rejected);
      await fixture.ready();

      await expectLater(
        fixture.client.get<Map<String, dynamic>>('/sessions'),
        throwsA(isA<ApiException>()),
      );

      expect(fixture.sessionExpired, isTrue);
    });

    test(
      'a network failure while refreshing does not end the session '
      'or wipe the persisted tokens',
      () async {
        // Regression: on Android, the first request right after a killed
        // process is relaunched can hit the network before it is ready
        // (DNS/connectivity not yet warm). That used to be indistinguishable
        // from the server rejecting the refresh token, so a transient blip
        // permanently signed the user out and deleted their refresh token.
        final fixture = _Fixture(_RefreshOutcome.networkFailure);
        await fixture.ready();

        await expectLater(
          fixture.client.get<Map<String, dynamic>>('/sessions'),
          throwsA(isA<ApiException>()),
        );

        expect(fixture.sessionExpired, isFalse);
        expect(await fixture.tokens.readRefreshToken(), 'valid-refresh');
      },
    );
  });
}
