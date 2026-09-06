import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/features/notification/data/notification_service.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  test('background unread count suppresses global errors', () async {
    final client = _MockApiClient();
    Options? requestOptions;
    when(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.notificationUnreadCount,
        options: any(named: 'options'),
        dedup: false,
      ),
    ).thenAnswer((invocation) async {
      requestOptions = invocation.namedArguments[#options] as Options?;
      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiEndpoints.notificationUnreadCount,
        ),
        data: const {
          'success': true,
          'data': {'count': 3},
        },
      );
    });

    expect(await NotificationService(client).unreadCount(), 3);
    expect(
      requestOptions?.extra?[ApiOptionKeys.skipGlobalError],
      isTrue,
    );
  });

  test('registers all metadata needed to target an app installation', () async {
    final client = _MockApiClient();
    when(
      () => client.post<void>(
        ApiEndpoints.notificationDevices,
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<void>(
        requestOptions: RequestOptions(path: ApiEndpoints.notificationDevices),
      ),
    );

    await NotificationService(client).registerDevice(
      token: 'fcm-token',
      platform: 'android',
      appVersion: '1.0.0+7',
      locale: 'vi',
      deviceId: 'installation-id',
    );

    final invocation = verify(
      () => client.post<void>(
        ApiEndpoints.notificationDevices,
        data: captureAny(named: 'data'),
        options: captureAny(named: 'options'),
      ),
    ).captured;
    expect(invocation.first, {
      'token': 'fcm-token',
      'platform': 'android',
      'appVersion': '1.0.0+7',
      'locale': 'vi',
      'deviceId': 'installation-id',
    });
    expect(
      (invocation.last as Options).extra?[ApiOptionKeys.skipGlobalError],
      isTrue,
    );
  });

  test('URL-encodes a token when unregistering the device', () async {
    final client = _MockApiClient();
    const path = '${ApiEndpoints.notificationDevices}/token%2Fwith%2Bsymbols';
    when(
      () => client.delete<void>(
        path,
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<void>(requestOptions: RequestOptions(path: path)),
    );

    await NotificationService(client).unregisterDevice('token/with+symbols');

    verify(
      () => client.delete<void>(path, options: any(named: 'options')),
    ).called(1);
  });
}
