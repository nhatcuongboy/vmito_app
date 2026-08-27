import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/social/data/newsfeed_badge_service.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient client;
  late NewsfeedBadgeService service;

  setUp(() {
    client = _MockApiClient();
    service = NewsfeedBadgeService(client);
  });

  test('reads the enveloped unread count from the users endpoint', () async {
    when(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.unreadFeedCount,
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiEndpoints.unreadFeedCount),
        data: const {
          'success': true,
          'data': {'count': 12},
        },
      ),
    );

    expect(await service.unreadCount(), 12);
  });

  test('defaults a missing or invalid count to zero', () async {
    when(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.unreadFeedCount,
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiEndpoints.unreadFeedCount),
        data: const {'success': true, 'data': <String, dynamic>{}},
      ),
    );

    expect(await service.unreadCount(), 0);
  });

  test('marks the feed through the users endpoint', () async {
    when(
      () => client.post<void>(
        ApiEndpoints.markFeedAsRead,
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<void>(
        requestOptions: RequestOptions(path: ApiEndpoints.markFeedAsRead),
      ),
    );

    await service.markAsRead();

    verify(
      () => client.post<void>(
        ApiEndpoints.markFeedAsRead,
        options: any(named: 'options'),
      ),
    ).called(1);
  });
}
