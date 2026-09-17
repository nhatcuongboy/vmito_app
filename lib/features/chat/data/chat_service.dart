import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/chat/domain/chat_contact.dart';
import 'package:vmito_app/features/chat/domain/chat_conversation.dart';
import 'package:vmito_app/features/chat/domain/chat_request.dart';
import 'package:vmito_app/features/chat/domain/chat_session.dart';

/// One method per `vmito-be` `ChatController` route. The backend never
/// carries message bodies — every call here is consent, discovery or the
/// request/decline/cancel handshake; the actual conversation happens over
/// Stream's own SDK/socket once a channel is active.
class ChatService {
  const ChatService(this._client);

  final ApiClient _client;

  Future<ChatSession> session() async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.chatSession,
      // A disabled/unconfigured backend must not surface the app-wide error
      // banner — the chat UI renders its own "unavailable" state instead.
      options: apiOptions(skipGlobalError: true),
      dedup: false,
    );
    return unwrap(response.data, ChatSession.fromJson);
  }

  Future<ChatSession> acceptTerms(String termsVersion) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.chatConsent,
      data: {'termsVersion': termsVersion},
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, ChatSession.fromJson);
  }

  Future<Page<ChatContact>> contacts({
    required String search,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.chatContacts,
      queryParameters: {'search': search, 'page': page, 'limit': limit},
      dedup: false,
    );
    return unwrapPage(response.data, ChatContact.fromJson);
  }

  Future<List<ChatRequest>> requests() async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.chatRequests,
      dedup: false,
    );
    return unwrapList(response.data, ChatRequest.fromJson);
  }

  Future<ChatConversation> sendRequest({
    required String targetUserId,
    required String text,
    required String idempotencyKey,
  }) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.chatRequests,
      data: {
        'targetUserId': targetUserId,
        'text': text,
        'idempotencyKey': idempotencyKey,
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, ChatConversation.fromJson);
  }

  Future<ChatConversation> declineRequest(String id) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.chatRequestDecline(id),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, ChatConversation.fromJson);
  }

  Future<ChatConversation> cancelRequest(String id) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.chatRequestCancel(id),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, ChatConversation.fromJson);
  }

  Future<ChatConversation> direct(String targetUserId) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.chatDirect,
      data: {'targetUserId': targetUserId},
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, ChatConversation.fromJson);
  }

  Future<void> block(String targetUserId) => _client.post<dynamic>(
    ApiEndpoints.chatBlocks,
    data: {'targetUserId': targetUserId},
    options: apiOptions(skipGlobalError: true),
  );

  Future<void> unblock(String targetUserId) => _client.delete<dynamic>(
    ApiEndpoints.chatUnblock(targetUserId),
    options: apiOptions(skipGlobalError: true),
  );
}

final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(ref.watch(apiClientProvider)),
);
