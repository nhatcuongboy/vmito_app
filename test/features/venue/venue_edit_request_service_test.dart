import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue_edit_request.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  test('posts the typed venue edit request contract', () async {
    final client = _MockApiClient();
    final service = VenueService(client);
    when(
      () => client.post<dynamic>(
        ApiEndpoints.venueRequests,
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiEndpoints.venueRequests),
      ),
    );

    await service.createEditRequest(
      venueId: 'venue-1',
      draft: const VenueEditRequestDraft(
        name: ' Sân A ',
        sportTypes: ['BADMINTON'],
        street: ' 12 Nguyễn Huệ ',
        newCity: 'Hồ Chí Minh',
        newDistrict: 'Phường Sài Gòn',
        website: ' ',
        note: ' Nguồn: chủ sân ',
      ),
    );

    final body =
        verify(
              () => client.post<dynamic>(
                ApiEndpoints.venueRequests,
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body['type'], 'UPDATE');
    expect(body['venueId'], 'venue-1');
    expect(body['payload'], {
      'name': 'Sân A',
      'sportTypes': ['BADMINTON'],
      'street': '12 Nguyễn Huệ',
      'newCity': 'Hồ Chí Minh',
      'newDistrict': 'Phường Sài Gòn',
      'note': 'Nguồn: chủ sân',
    });
  });
}
