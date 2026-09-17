import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_conversation.freezed.dart';
part 'chat_conversation.g.dart';

/// Mirrors `ChatConversationStatus` in `vmito-be/prisma/schema.prisma`.
@JsonEnum(alwaysCreate: true)
enum ChatConversationStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('ACTIVE')
  active,
  @JsonValue('DECLINED')
  declined,
  @JsonValue('CANCELLED')
  cancelled,
}

@freezed
abstract class ChatConversationChannel with _$ChatConversationChannel {
  const factory ChatConversationChannel({
    required String type,
    required String id,
    required String cid,
  }) = _ChatConversationChannel;

  factory ChatConversationChannel.fromJson(Map<String, dynamic> json) =>
      _$ChatConversationChannelFromJson(json);
}

/// The response shape shared by `POST /chat/requests`, `/decline`, `/cancel`
/// and `POST /chat/direct` — see `chatService.conversationResponse()` in
/// `vmito-be/src/chat/chat.service.ts`.
@freezed
abstract class ChatConversation with _$ChatConversation {
  const factory ChatConversation({
    required String id,
    required ChatConversationStatus status,
    required ChatConversationChannel channel,
  }) = _ChatConversation;

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      _$ChatConversationFromJson(json);
}
