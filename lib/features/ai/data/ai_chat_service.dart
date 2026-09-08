import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/features/ai/domain/ai_chat_message.dart';

/// HTTP boundary for the server-owned Gemini assistant.
///
/// The app never receives the Gemini key: this sends its authenticated request
/// to `vmito-be /ai/chat` and yields the backend's text chunks as they arrive.
// ignore: one_member_abstracts
abstract interface class AiChatService {
  Stream<String> streamChat({
    required List<AiChatMessage> messages,
    required String language,
    String? pageContext,
    CancelToken? cancelToken,
  });
}

class ApiAiChatService implements AiChatService {
  const ApiAiChatService(this._client);

  final ApiClient _client;

  @override
  Stream<String> streamChat({
    required List<AiChatMessage> messages,
    required String language,
    String? pageContext,
    CancelToken? cancelToken,
  }) async* {
    final response = await _client.postStream(
      ApiEndpoints.aiChat,
      data: {
        'messages': messages
            .map((message) => message.toRequestJson())
            .toList(
              growable: false,
            ),
        if (pageContext != null && pageContext.trim().isNotEmpty)
          'pageContext': pageContext,
        'language': language,
      },
      cancelToken: cancelToken,
      options: apiOptions(skipGlobalError: true),
    );
    final body = response.data;
    if (body == null) {
      throw StateError('AI chat response body was empty.');
    }
    yield* body.stream.cast<List<int>>().transform(utf8.decoder);
  }
}

final aiChatServiceProvider = Provider<AiChatService>(
  (ref) => ApiAiChatService(ref.watch(apiClientProvider)),
);
