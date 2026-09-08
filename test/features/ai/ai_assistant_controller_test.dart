import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/features/ai/application/ai_assistant_controller.dart';
import 'package:vmito_app/features/ai/data/ai_chat_service.dart';
import 'package:vmito_app/features/ai/domain/ai_chat_message.dart';

class _FakeAiChatService implements AiChatService {
  final chunks = StreamController<String>();
  List<AiChatMessage>? requestedMessages;
  String? language;
  String? pageContext;
  CancelToken? cancelToken;

  @override
  Stream<String> streamChat({
    required List<AiChatMessage> messages,
    required String language,
    String? pageContext,
    CancelToken? cancelToken,
  }) {
    requestedMessages = messages;
    this.language = language;
    this.pageContext = pageContext;
    this.cancelToken = cancelToken;
    return chunks.stream;
  }

  Future<void> dispose() => chunks.close();
}

class _ChineseLocaleController extends LocaleController {
  @override
  Locale build() => const Locale('zh');
}

ProviderContainer _container(_FakeAiChatService service) => ProviderContainer(
  overrides: [
    aiChatServiceProvider.overrideWithValue(service),
    localeControllerProvider.overrideWith(_ChineseLocaleController.new),
  ],
);

void main() {
  group('AiAssistantController', () {
    test(
      'streams an assistant reply and maps Chinese locale to backend cn',
      () async {
        final service = _FakeAiChatService();
        final container = _container(service);
        addTearDown(() async {
          await service.dispose();
          container.dispose();
        });

        final future = container
            .read(aiAssistantControllerProvider.notifier)
            .sendMessage(
              text: '  Giúp tôi tìm kèo  ',
              pageContext: 'Trang chủ Vmito',
              errorMessage: 'Lỗi',
            );
        await Future<void>.delayed(Duration.zero);

        expect(service.requestedMessages, hasLength(1));
        expect(service.requestedMessages!.single.content, 'Giúp tôi tìm kèo');
        expect(service.language, 'cn');
        expect(service.pageContext, 'Trang chủ Vmito');
        expect(
          container.read(aiAssistantControllerProvider).messages,
          hasLength(2),
        );

        service.chunks
          ..add('Bạn có thể ')
          ..add('mở danh sách kèo.');
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(aiAssistantControllerProvider).messages.last.content,
          'Bạn có thể mở danh sách kèo.',
        );

        await service.chunks.close();
        await future;
        expect(
          container.read(aiAssistantControllerProvider).isStreaming,
          isFalse,
        );
      },
    );

    test(
      'stopping preserves partial content and clear removes the session history',
      () async {
        final service = _FakeAiChatService();
        final container = _container(service);
        addTearDown(() async {
          await service.dispose();
          container.dispose();
        });

        final future = container
            .read(aiAssistantControllerProvider.notifier)
            .sendMessage(
              text: 'Help',
              pageContext: 'Home',
              errorMessage: 'Error',
            );
        await Future<void>.delayed(Duration.zero);
        service.chunks.add('Partial');
        await Future<void>.delayed(Duration.zero);

        final controller = container.read(
          aiAssistantControllerProvider.notifier,
        )..stopStreaming();
        expect(
          container.read(aiAssistantControllerProvider).isStreaming,
          isFalse,
        );
        expect(
          container.read(aiAssistantControllerProvider).messages.last.content,
          'Partial',
        );

        controller.clearMessages();
        expect(container.read(aiAssistantControllerProvider).messages, isEmpty);
        await service.chunks.close();
        await future;
      },
    );
  });
}
