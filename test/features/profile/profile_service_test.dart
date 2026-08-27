import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/profile/data/profile_service.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _response(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/test'),
      data: {'success': true, 'data': data},
    );

Map<String, dynamic> _userJson() => {
  'id': 'user-1',
  'email': 'player@example.test',
  'name': 'Player',
  'role': 'PLAYER',
  'level': 5,
  'levelDescription': 'Intermediate',
};

void main() {
  late _MockApiClient client;
  late ProfileService service;

  setUp(() {
    client = _MockApiClient();
    service = ProfileService(
      client,
      imageCompressor: (bytes) async => bytes,
    );
  });

  test('loads and updates the full user contract', () async {
    when(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.user('user-1'),
        dedup: false,
      ),
    ).thenAnswer((_) async => _response(_userJson()));
    when(
      () => client.put<Map<String, dynamic>>(
        ApiEndpoints.user('user-1'),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _response(_userJson()));

    final loaded = await service.user('user-1');
    final updated = await service.updateUser('user-1', {'name': 'Player'});

    expect(loaded.level, 5);
    expect(loaded.levelDescription, 'Intermediate');
    expect(updated.name, 'Player');
  });

  test(
    'uploads avatar using the expected multipart field and progress',
    () async {
      var progress = 0;
      when(
        () => client.post<Map<String, dynamic>>(
          ApiEndpoints.uploadAvatar,
          data: any(named: 'data'),
          options: any(named: 'options'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.namedArguments[#onSendProgress]! as ProgressCallback;
        callback(50, 100);
        return _response({
          'url': 'https://example.test/avatar.jpg',
          'publicId': 'avatars/user-1',
        });
      });

      final asset = await service.uploadAvatar(
        Uint8List.fromList([1, 2, 3]),
        filename: 'portrait.png',
        onProgress: (value) => progress = value,
      );

      expect(progress, 50);
      expect(asset.publicId, 'avatars/user-1');
      final formData =
          verify(
                () => client.post<Map<String, dynamic>>(
                  ApiEndpoints.uploadAvatar,
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                  onSendProgress: any(named: 'onSendProgress'),
                ),
              ).captured.single
              as FormData;
      expect(formData.files.single.key, 'avatar');
      expect(formData.files.single.value.filename, 'portrait.jpg');
    },
  );
}
