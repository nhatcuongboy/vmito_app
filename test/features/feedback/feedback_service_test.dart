import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/feedback/data/feedback_service.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(dynamic data) => Response<dynamic>(
  requestOptions: RequestOptions(path: ApiEndpoints.feedback),
  data: data,
);

Map<String, dynamic> _itemJson() => {
  'id': 'feedback-1',
  'type': 'CONTACT',
  'status': 'PENDING',
  'title': 'Hello',
  'description': 'Details',
  'createdAt': '2026-08-25T00:00:00.000Z',
};

void main() {
  late _MockApiClient client;
  late FeedbackService service;

  setUp(() {
    client = _MockApiClient();
    service = FeedbackService(client);
  });

  test('lists and unwraps the current user feedback', () async {
    when(
      () => client.get<dynamic>(ApiEndpoints.feedback),
    ).thenAnswer(
      (_) async => _response({
        'success': true,
        'data': [_itemJson()],
      }),
    );

    final items = await service.listMine();

    expect(items.single.id, 'feedback-1');
  });

  test('uploads a multipart screenshot', () async {
    when(
      () => client.post<dynamic>(
        ApiEndpoints.feedbackUploadImage,
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => _response({
        'success': true,
        'data': {
          'imageUrl': 'https://example.com/image.jpg',
          'imagePublicId': 'feedback/image',
        },
      }),
    );

    final attachment = await service.uploadImage(
      bytes: [1, 2, 3],
      filename: 'bug.jpg',
    );

    expect(attachment.imagePublicId, 'feedback/image');
    final formData =
        verify(
              () => client.post<dynamic>(
                ApiEndpoints.feedbackUploadImage,
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as FormData;
    expect(formData.files.single.key, 'file');
  });

  test('posts the backend feedback contract', () async {
    when(
      () => client.post<dynamic>(
        ApiEndpoints.feedback,
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => _response({'success': true, 'data': _itemJson()}),
    );

    await service.create(
      const FeedbackDraft(
        type: FeedbackType.contact,
        title: 'Hello',
        description: 'Details',
      ),
    );

    final body =
        verify(
              () => client.post<dynamic>(
                ApiEndpoints.feedback,
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body, {
      'type': 'CONTACT',
      'title': 'Hello',
      'description': 'Details',
    });
  });
}
