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
}
