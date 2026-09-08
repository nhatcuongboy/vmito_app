enum AiChatRole { user, assistant }

/// A single turn kept in the in-memory AI-assistant conversation.
class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final AiChatRole role;
  final String content;
  final DateTime createdAt;

  AiChatMessage copyWith({String? content}) => AiChatMessage(
    id: id,
    role: role,
    content: content ?? this.content,
    createdAt: createdAt,
  );

  Map<String, String> toRequestJson() => {
    'role': role.name,
    'content': content,
  };
}
