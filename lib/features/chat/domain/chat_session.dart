import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_session.freezed.dart';
part 'chat_session.g.dart';

/// `GET /chat/session` / `POST /chat/consent` response.
///
/// `apiKey`, `token` and `expiresAt` are only present once `enabled &&
/// consented` — see `vmito-be/src/chat/chat.service.ts#getSession`. `token`
/// is short-lived (1h); `ChatSessionController` refetches this before it
/// expires rather than caching it.
@freezed
abstract class ChatSession with _$ChatSession {
  const factory ChatSession({
    required bool enabled,
    required bool consented,
    required String termsVersion,
    @Default(0) int pendingRequestCount,
    String? apiKey,
    String? token,
    DateTime? expiresAt,

    /// Only present on the response to `POST /chat/consent`: how many of the
    /// caller's incoming pending requests just auto-activated.
    int? activatedCount,
  }) = _ChatSession;

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);

  const ChatSession._();

  /// Ready to construct a `StreamChatClient` and connect.
  bool get isConnectable =>
      enabled && consented && apiKey != null && token != null;
}
