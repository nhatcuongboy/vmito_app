import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/chat/application/chat_requests_controller.dart';
import 'package:vmito_app/features/chat/application/chat_session_controller.dart';
import 'package:vmito_app/features/chat/domain/chat_request.dart';
import 'package:vmito_app/features/chat/domain/form/chat_consent_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// First-run chat terms gate. Rendered by `ChatInboxScreen` and
/// `NewChatScreen` in place of their normal content whenever the session
/// hasn't consented yet — not a separate route, so there is nowhere for a
/// half-consented user to land.
///
/// Also the *only* place pending incoming requests are individually
/// declinable: consenting activates every one of them at once
/// (`reconcilePendingFor` in `vmito-be/src/chat/chat.service.ts`), so a
/// request the recipient wants to reject has to be declined *before* they
/// accept the terms generally.
class ChatConsentView extends ConsumerStatefulWidget {
  const ChatConsentView({
    required this.termsVersion,
    required this.pendingRequestCount,
    super.key,
  });

  final String termsVersion;
  final int pendingRequestCount;

  @override
  ConsumerState<ChatConsentView> createState() => _ChatConsentViewState();
}

class _ChatConsentViewState extends ConsumerState<ChatConsentView> {
  late final FormGroup _form;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  Object? _submitError;

  @override
  void initState() {
    super.initState();
    _form = createChatConsentForm();
    if (widget.pendingRequestCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(
          ref.read(chatRequestsControllerProvider.notifier).load(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _hasSubmitted = true);
    _form.markAllAsTouched();
    if (_form.invalid || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await ref.read(chatSessionControllerProvider.notifier).acceptTerms();
    } on Object catch (error) {
      if (mounted) setState(() => _submitError = error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final acceptedControl =
        _form.control(ChatConsentFormControl.accepted) as FormControl<bool>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppReactiveForm<void>(
            formGroup: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(AppIcons.chat, size: 40, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.chatConsentTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.chatConsentBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
                if (widget.pendingRequestCount > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const _PendingRequestsSection(),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (_submitError != null) ...[
                  Text(
                    _errorMessage(_submitError!),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    acceptedControl
                      ..markAsTouched()
                      ..updateValue(!(acceptedControl.value ?? false));
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      ReactiveCheckbox(
                        key: const ValueKey('chat-consent-checkbox'),
                        formControlName: ChatConsentFormControl.accepted,
                        activeColor: theme.colorScheme.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(text: l10n.chatConsentTermsPrefix),
                              WidgetSpan(
                                child: _TermsLinkButton(
                                  label: l10n.legalTermsTab,
                                  onPressed: () =>
                                      context.push(AppRoutes.terms),
                                ),
                              ),
                              TextSpan(text: l10n.chatConsentTermsConnector),
                              WidgetSpan(
                                child: _TermsLinkButton(
                                  label: l10n.legalPrivacyTab,
                                  onPressed: () =>
                                      context.push(AppRoutes.privacy),
                                ),
                              ),
                              TextSpan(text: l10n.chatConsentTermsSuffix),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if ((_hasSubmitted || acceptedControl.touched) &&
                    acceptedControl.hasError(ValidationMessage.requiredTrue))
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      left: 28,
                    ),
                    child: Text(
                      l10n.chatConsentCheckboxRequired,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const Key('chat-consent-submit'),
                  onPressed: _isSubmitting ? null : () => unawaited(_submit()),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.chatConsentSubmit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object error) => error is ApiException
      ? error.message
      : AppLocalizations.of(context).chatConsentError;
}

class _PendingRequestsSection extends ConsumerWidget {
  const _PendingRequestsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final state = ref.watch(chatRequestsControllerProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.muted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatPendingRequestsSection,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            for (final request in state.requests)
              _PendingRequestTile(request: request),
        ],
      ),
    );
  }
}

class _PendingRequestTile extends ConsumerStatefulWidget {
  const _PendingRequestTile({required this.request});

  final ChatRequest request;

  @override
  ConsumerState<_PendingRequestTile> createState() =>
      _PendingRequestTileState();
}

class _PendingRequestTileState extends ConsumerState<_PendingRequestTile> {
  bool _isDeclining = false;

  Future<void> _decline() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatDeclineConfirmTitle),
        content: Text(
          l10n.chatDeclineConfirmBody(widget.request.sender.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.chatDeclineAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeclining = true);
    try {
      await ref
          .read(chatRequestsControllerProvider.notifier)
          .decline(widget.request.id);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException ? error.message : l10n.chatConsentError,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeclining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sender = widget.request.sender;
    final image = sender.image;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: (image != null && image.isNotEmpty)
                ? CachedNetworkImageProvider(image)
                : null,
            child: (image == null || image.isEmpty)
                ? Text(
                    sender.name.isNotEmpty ? sender.name[0].toUpperCase() : '?',
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(sender.name, overflow: TextOverflow.ellipsis),
          ),
          if (_isDeclining)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: () => unawaited(_decline()),
              child: Text(l10n.chatDeclineAction),
            ),
        ],
      ),
    );
  }
}

class _TermsLinkButton extends StatelessWidget {
  const _TermsLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}
