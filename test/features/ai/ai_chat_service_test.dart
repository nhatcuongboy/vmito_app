import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/ai/data/ai_chat_service.dart';
import 'package:vmito_app/features/ai/domain/ai_chat_message.dart';

import '../../support/fake_secure_storage.dart';

class _StreamingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  String? requestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final bytes = <int>[];
    await requestStream?.forEach(bytes.addAll);
    requestBody = utf8.decode(bytes);
    return ResponseBody(
      Stream.fromIterable([
        Uint8List.fromList(utf8.encode('Xin ')),
        Uint8List.fromList(utf8.encode('chào 👋')),
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiAiChatService _service(_StreamingAdapter adapter) {
  final client = buildApiClient(
    tokenStorage: TokenStorage(FakeSecureStorage()),
    errorBus: ApiErrorBus(),
    onSessionExpired: () async {},
  );
  client.raw.httpClientAdapter = adapter;
  return ApiAiChatService(client);
}

void main() {
  test(
    'streams UTF-8 chunks and posts the documented assistant payload',
    () async {
      final adapter = _StreamingAdapter();
      final service = _service(adapter);

      final chunks = await service
          .streamChat(
            messages: [
              AiChatMessage(
                id: 'u1',
                role: AiChatRole.user,
                content: 'Xin chào',
                createdAt: DateTime(2026),
              ),
            ],
            language: 'vi',
            pageContext: 'Trang chủ Vmito',
          )
          .toList();

      expect(chunks.join(), 'Xin chào 👋');
      expect(adapter.request!.path, '/ai/chat');
      expect(adapter.request!.responseType, ResponseType.stream);
      expect(jsonDecode(adapter.requestBody!), {
        'messages': [
          {'role': 'user', 'content': 'Xin chào'},
        ],
        'pageContext': 'Trang chủ Vmito',
        'language': 'vi',
      });
    },
  );
}
