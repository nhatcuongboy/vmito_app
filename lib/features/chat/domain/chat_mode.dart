import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_mode.g.dart';

/// Mirrors `ChatMode` in `vmito-be/src/chat/chat.service.ts`.
///
/// Whether the caller can message a given user right now, or must send a
/// request first because the target hasn't accepted chat terms yet.
@JsonEnum(alwaysCreate: true)
enum ChatMode {
  /// Both sides have consented — `POST /chat/direct` opens the DM instantly.
  @JsonValue('DIRECT')
  direct,

  /// The target hasn't consented yet — `POST /chat/requests` sends one
  /// initial message that becomes a pending request.
  @JsonValue('REQUEST')
  request,

  /// Blocked, self, or chat is disabled. No messaging surface is shown.
  @JsonValue('UNAVAILABLE')
  unavailable,
}

extension ChatModeWire on ChatMode {
  /// For hand-written `fromJson` factories (e.g. `PublicProfile`) that don't
  /// go through json_serializable's generated enum map.
  static ChatMode fromWire(String? value) => switch (value) {
    'DIRECT' => ChatMode.direct,
    'REQUEST' => ChatMode.request,
    _ => ChatMode.unavailable,
  };

  String get wireValue => switch (this) {
    ChatMode.direct => 'DIRECT',
    ChatMode.request => 'REQUEST',
    ChatMode.unavailable => 'UNAVAILABLE',
  };
}
