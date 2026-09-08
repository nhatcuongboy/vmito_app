import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/ai/application/ai_assistant_controller.dart';
import 'package:vmito_app/features/ai/domain/ai_chat_message.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

abstract final class _AiFormControl {
  static const message = 'message';
}

/// Opens the assistant after an external entry point (such as the drawer) has
/// finished its own navigation transition.
Future<void> showAiAssistantSheet(
  BuildContext context, {
  required String routePath,
  required VoidCallback onClosed,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AiAssistantSheet(routePath: routePath),
  );
  onClosed();
}

/// A draggable mobile conversation surface. It owns only the composer form;
/// [AiAssistantController] retains conversation state while the app runs.
class AiAssistantSheet extends ConsumerStatefulWidget {
  const AiAssistantSheet({required this.routePath, super.key});

  final String routePath;

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet> {
  final _form = FormGroup({
    _AiFormControl.message: FormControl<String>(
      validators: [Validators.required],
    ),
  });
  final _messagesController = ScrollController();
  ProviderSubscription<AiAssistantState>? _assistantSubscription;

  @override
  void initState() {
    super.initState();
    _assistantSubscription = ref.listenManual<AiAssistantState>(
      aiAssistantControllerProvider,
      (_, _) => _scrollToLatest(),
    );
  }

  @override
  void dispose() {
    _assistantSubscription?.close();
    _form.dispose();
    _messagesController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesController.hasClients) return;
      unawaited(
        _messagesController.animateTo(
          _messagesController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _send() {
    _form.markAsSubmitted();
    if (_form.invalid || _form.pending) return;
    final message = _form.control(_AiFormControl.message).value as String;
    final l10n = AppLocalizations.of(context);
    ref
        .read(aiAssistantControllerProvider.notifier)
        .sendMessage(
          text: message,
          pageContext: _pageContext(widget.routePath, context),
          errorMessage: l10n.aiAssistantErrorMessage,
        )
        .ignore();
    _form.reset();
  }

  void _sendSuggestedQuestion(String question) {
    _form.control(_AiFormControl.message).value = question;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantControllerProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .94,
      minChildSize: .62,
      maxChildSize: .98,
      builder: (context, _) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        child: Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              _Header(
                hasMessages: state.messages.isNotEmpty,
                onClear: ref
                    .read(aiAssistantControllerProvider.notifier)
                    .clearMessages,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: state.messages.isEmpty
                    ? _Welcome(
                        suggestions: _suggestions(widget.routePath, context),
                        onSuggestionTap: _sendSuggestedQuestion,
                      )
                    : ListView.builder(
                        key: const Key('ai-assistant-messages'),
                        controller: _messagesController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) => _MessageBubble(
                          message: state.messages[index],
                        ),
                      ),
              ),
              _Composer(
                form: _form,
                isStreaming: state.isStreaming,
                onSend: _send,
                onStop: ref
                    .read(aiAssistantControllerProvider.notifier)
                    .stopStreaming,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasMessages,
    required this.onClear,
    required this.onClose,
  });

  final bool hasMessages;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0x33FFFFFF),
            foregroundColor: Colors.white,
            child: Icon(AppIcons.sparkles, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aiAssistantTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.aiAssistantProvider,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .82),
                  ),
                ),
              ],
            ),
          ),
          if (hasMessages)
            IconButton(
              key: const Key('ai-assistant-clear'),
              tooltip: l10n.aiAssistantClearHistory,
              color: Colors.white,
              onPressed: onClear,
              icon: const Icon(AppIcons.delete, size: 19),
            ),
          IconButton(
            key: const Key('ai-assistant-close'),
            tooltip: l10n.aiAssistantClose,
            color: Colors.white,
            onPressed: onClose,
            icon: const Icon(AppIcons.close),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.suggestions, required this.onSuggestionTap});

  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mutedForeground = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.sm),
        const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          child: Icon(AppIcons.sparkles, size: 28),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.aiAssistantWelcomeTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.aiAssistantWelcomeDescription,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          l10n.aiAssistantSuggestedQuestions.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: mutedForeground,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final question in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              onPressed: () => onSuggestionTap(question),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
                side: const BorderSide(color: Color(0xFFC4B5FD)),
                foregroundColor: const Color(0xFF6D28D9),
              ),
              child: Text(question),
            ),
          ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.form,
    required this.isStreaming,
    required this.onSend,
    required this.onStop,
  });

  final FormGroup form;
  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: AppReactiveForm<Object?>(
          formGroup: form,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ReactiveTextField<String>(
                    key: const Key('ai-assistant-composer'),
                    formControlName: _AiFormControl.message,
                    readOnly: isStreaming,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l10n.aiAssistantPlaceholder,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ReactiveFormConsumer(
                  builder: (context, formGroup, child) => IconButton.filled(
                    key: const Key('ai-assistant-send'),
                    tooltip: isStreaming
                        ? l10n.aiAssistantStop
                        : l10n.aiAssistantSend,
                    onPressed: isStreaming
                        ? onStop
                        : formGroup.valid
                        ? onSend
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: isStreaming
                          ? theme.colorScheme.error
                          : const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      isStreaming ? AppIcons.stop : AppIcons.send,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiChatRole.user;
    final theme = Theme.of(context);
    final content = message.content;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              child: Icon(AppIcons.sparkles, size: 14),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF7C3AED)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: content.isEmpty && !isUser
                    ? const _TypingIndicator()
                    : _BasicMarkdownText(
                        content: content,
                        color: isUser
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 24,
    height: 16,
    child: Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

/// Deliberately small, safe markdown subset matching the web assistant.
class _BasicMarkdownText extends StatelessWidget {
  const _BasicMarkdownText({required this.content, required this.color});

  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: color,
      height: 1.45,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in content.split('\n'))
          if (line.startsWith('- ') || line.startsWith('• '))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 7),
                    child: Icon(Icons.circle, size: 5, color: color),
                  ),
                  Expanded(child: _StyledLine(line.substring(2), style)),
                ],
              ),
            )
          else if (line.startsWith('## '))
            Padding(
              padding: const EdgeInsets.only(bottom: 4, top: 3),
              child: _StyledLine(
                line.substring(3),
                style.copyWith(fontWeight: FontWeight.w700),
              ),
            )
          else if (line.isEmpty)
            const SizedBox(height: 5)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _StyledLine(line, style),
            ),
      ],
    );
  }
}

class _StyledLine extends StatelessWidget {
  const _StyledLine(this.value, this.style);

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final parts = value.split(RegExp(r'(\*\*[^*]+\*\*)'));
    return Text.rich(
      TextSpan(
        children: [
          for (final part in parts)
            TextSpan(
              text: part.startsWith('**') && part.endsWith('**')
                  ? part.substring(2, part.length - 2)
                  : part,
              style: part.startsWith('**') && part.endsWith('**')
                  ? style.copyWith(fontWeight: FontWeight.w700)
                  : style,
            ),
        ],
      ),
    );
  }
}

String _pageContext(String path, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  if (path == AppRoutes.createSession) return l10n.aiAssistantContextCreate;
  if (path.startsWith(AppRoutes.transactions)) {
    return l10n.aiAssistantContextPayments;
  }
  if (path.startsWith(AppRoutes.tournaments)) {
    return l10n.aiAssistantContextTournaments;
  }
  if (path.startsWith(AppRoutes.venues)) return l10n.aiAssistantContextVenues;
  if (path.startsWith(AppRoutes.clubs) ||
      path.startsWith(AppRoutes.manageClubs)) {
    return l10n.aiAssistantContextClubs;
  }
  if (path.startsWith(AppRoutes.profile) || path.startsWith('/user/')) {
    return l10n.aiAssistantContextProfile;
  }
  if (path.contains('/manage')) return l10n.aiAssistantContextHostSessions;
  if (path.startsWith(AppRoutes.browseSessions)) {
    return l10n.aiAssistantContextSessions;
  }
  return l10n.aiAssistantContextHome;
}

List<String> _suggestions(String path, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  if (path == AppRoutes.createSession) {
    return [
      l10n.aiAssistantSuggestionCreate1,
      l10n.aiAssistantSuggestionCreate2,
      l10n.aiAssistantSuggestionCreate3,
      l10n.aiAssistantSuggestionCreate4,
      l10n.aiAssistantSuggestionCreate5,
    ];
  }
  if (path.startsWith(AppRoutes.transactions)) {
    return [
      l10n.aiAssistantSuggestionPayment1,
      l10n.aiAssistantSuggestionPayment2,
      l10n.aiAssistantSuggestionPayment3,
      l10n.aiAssistantSuggestionPayment4,
      l10n.aiAssistantSuggestionPayment5,
    ];
  }
  if (path.startsWith(AppRoutes.tournaments)) {
    return [
      l10n.aiAssistantSuggestionTournament1,
      l10n.aiAssistantSuggestionTournament2,
      l10n.aiAssistantSuggestionTournament3,
      l10n.aiAssistantSuggestionTournament4,
      l10n.aiAssistantSuggestionTournament5,
    ];
  }
  if (path.startsWith(AppRoutes.venues)) {
    return [
      l10n.aiAssistantSuggestionVenue1,
      l10n.aiAssistantSuggestionVenue2,
      l10n.aiAssistantSuggestionVenue3,
      l10n.aiAssistantSuggestionVenue4,
      l10n.aiAssistantSuggestionVenue5,
    ];
  }
  if (path.startsWith(AppRoutes.clubs) ||
      path.startsWith(AppRoutes.manageClubs)) {
    return [
      l10n.aiAssistantSuggestionClub1,
      l10n.aiAssistantSuggestionClub2,
      l10n.aiAssistantSuggestionClub3,
      l10n.aiAssistantSuggestionClub4,
      l10n.aiAssistantSuggestionClub5,
    ];
  }
  if (path.startsWith(AppRoutes.profile) || path.startsWith('/user/')) {
    return [
      l10n.aiAssistantSuggestionProfile1,
      l10n.aiAssistantSuggestionProfile2,
      l10n.aiAssistantSuggestionProfile3,
      l10n.aiAssistantSuggestionProfile4,
      l10n.aiAssistantSuggestionProfile5,
    ];
  }
  if (path.startsWith(AppRoutes.browseSessions)) {
    return [
      l10n.aiAssistantSuggestionSession1,
      l10n.aiAssistantSuggestionSession2,
      l10n.aiAssistantSuggestionSession3,
      l10n.aiAssistantSuggestionSession4,
      l10n.aiAssistantSuggestionSession5,
    ];
  }
  return [
    l10n.aiAssistantSuggestionGeneral1,
    l10n.aiAssistantSuggestionGeneral2,
    l10n.aiAssistantSuggestionGeneral3,
    l10n.aiAssistantSuggestionGeneral4,
    l10n.aiAssistantSuggestionGeneral5,
  ];
}
