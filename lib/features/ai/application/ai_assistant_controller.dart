import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/features/ai/data/ai_chat_service.dart';
import 'package:vmito_app/features/ai/domain/ai_chat_message.dart';
import 'package:vmito_app/features/session/data/session_form_service.dart';

/// Mirrors the web assistant's feature-flag behavior: wait for the first
/// response, honor an explicit backend value, and otherwise use the web's
/// enabled default so a transient flags outage does not hide the assistant.
final aiAssistantFeatureEnabledProvider = Provider<bool>((ref) {
  final flags = ref.watch(sessionFeatureFlagsProvider);
  return flags.when(
    data: (value) => value['AI_FEATURE_ENABLED'] ?? true,
    loading: () => false,
    error: (_, _) => true,
  );
});

class AiAssistantState {
  const AiAssistantState({
    this.messages = const [],
    this.isStreaming = false,
  });

  final List<AiChatMessage> messages;
  final bool isStreaming;

  AiAssistantState copyWith({
    List<AiChatMessage>? messages,
    bool? isStreaming,
  }) => AiAssistantState(
    messages: messages ?? this.messages,
    isStreaming: isStreaming ?? this.isStreaming,
  );
}

/// Owns the transient conversation for the lifetime of the application.
class AiAssistantController extends Notifier<AiAssistantState> {
  CancelToken? _cancelToken;
  int _nextId = 0;

  @override
  AiAssistantState build() {
    ref.onDispose(
      () => _cancelToken?.cancel('AI assistant controller was disposed.'),
    );
    return const AiAssistantState();
  }

  Future<void> sendMessage({
    required String text,
    required String pageContext,
    required String errorMessage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isStreaming) return;

    final now = DateTime.now();
    final userMessage = AiChatMessage(
      id: _messageId('user'),
      role: AiChatRole.user,
      content: trimmed,
      createdAt: now,
    );
    final assistantMessage = AiChatMessage(
      id: _messageId('assistant'),
      role: AiChatRole.assistant,
      content: '',
      createdAt: now,
    );
    final requestMessages = [...state.messages, userMessage];
    final visibleMessages = [...requestMessages, assistantMessage];
    final cancelToken = _cancelToken = CancelToken();
    state = state.copyWith(messages: visibleMessages, isStreaming: true);

    try {
      final language = ref.read(localeControllerProvider).languageCode;
      await for (final chunk
          in ref
              .read(aiChatServiceProvider)
              .streamChat(
                messages: requestMessages,
                language: language == 'zh' ? 'cn' : language,
                pageContext: pageContext,
                cancelToken: cancelToken,
              )) {
        if (!identical(_cancelToken, cancelToken)) return;
        _replaceAssistantContent(assistantMessage.id, chunk, append: true);
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) ||
          !identical(_cancelToken, cancelToken)) {
        return;
      }
      _replaceAssistantContent(assistantMessage.id, errorMessage);
    } on Object {
      if (!identical(_cancelToken, cancelToken)) return;
      _replaceAssistantContent(assistantMessage.id, errorMessage);
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
        state = state.copyWith(isStreaming: false);
      }
    }
  }

  void clearMessages() {
    stopStreaming();
    state = const AiAssistantState();
  }

  void stopStreaming() {
    _cancelToken?.cancel('AI assistant closed or stopped by the user.');
    _cancelToken = null;
    if (state.isStreaming) state = state.copyWith(isStreaming: false);
  }

  String _messageId(String role) => '$role-${_nextId++}';

  void _replaceAssistantContent(
    String id,
    String content, {
    bool append = false,
  }) {
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          if (message.id == id)
            message.copyWith(
              content: append ? '${message.content}$content' : content,
            )
          else
            message,
      ],
    );
  }
}

final aiAssistantControllerProvider =
    NotifierProvider<AiAssistantController, AiAssistantState>(
      AiAssistantController.new,
    );
