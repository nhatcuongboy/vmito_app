import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

class SessionRatingScreen extends ConsumerWidget {
  const SessionRatingScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionDetailProvider(sessionId));
    final eligibility = ref.watch(ratingEligibilityProvider(sessionId));
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.socialRateSession)),
      body: session.when(
        data: (sessionValue) => eligibility.when(
          data: (value) {
            if (value.isEmpty) {
              return Center(child: Text(l10n.socialNothingToRate));
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                if (value.canRateHost && sessionValue.host != null)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(AppIcons.verified),
                      ),
                      title: Text(sessionValue.displayHostName),
                      subtitle: Text(l10n.socialRateHost),
                      trailing: const Icon(AppIcons.chevronRight),
                      onTap: () => _showRatingDialog(
                        context,
                        ref,
                        userId: sessionValue.host!.id,
                        name: sessionValue.displayHostName,
                        type: 'PLAYER_TO_HOST',
                      ),
                    ),
                  ),
                for (final userId in value.canRatePlayers)
                  _RatePlayerTile(sessionId: sessionId, userId: userId),
              ],
            );
          },
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(ratingEligibilityProvider(sessionId)),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => AppErrorView(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _showRatingDialog(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    required String name,
    required String type,
  }) => showRatingDialog(
    context,
    ref,
    sessionId: sessionId,
    userId: userId,
    name: name,
    type: type,
  );
}

class _RatePlayerTile extends ConsumerWidget {
  const _RatePlayerTile({required this.sessionId, required this.userId});

  final String sessionId;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicUserProvider(userId));
    return profile.when(
      data: (value) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(AppIcons.profile),
          ),
          title: Text(value.name),
          subtitle: Text(AppLocalizations.of(context).socialRatePlayer),
          trailing: const Icon(AppIcons.chevronRight),
          onTap: () => showRatingDialog(
            context,
            ref,
            sessionId: sessionId,
            userId: userId,
            name: value.name,
            type: 'HOST_TO_PLAYER',
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('…'),
        ),
      ),
    );
  }
}

Future<void> showRatingDialog(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  required String userId,
  required String name,
  required String type,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RatingDialog(
      sessionId: sessionId,
      userId: userId,
      name: name,
      type: type,
    ),
  );
}

class _RatingDialog extends ConsumerStatefulWidget {
  const _RatingDialog({
    required this.sessionId,
    required this.userId,
    required this.name,
    required this.type,
  });
  final String sessionId;
  final String userId;
  final String name;
  final String type;
  @override
  ConsumerState<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<_RatingDialog> {
  late final FormGroup _form = FormGroup({
    'rating': FormControl<int>(
      value: 5,
      validators: [Validators.required, Validators.min(1), Validators.max(5)],
    ),
    'comment': FormControl<String>(validators: [Validators.maxLength(500)]),
  });
  bool _submitting = false;
  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(socialServiceProvider)
          .createRating(
            sessionId: widget.sessionId,
            ratedUserId: widget.userId,
            type: widget.type,
            rating: _form.control('rating').value as int,
            comment: (_form.control('comment').value as String?) ?? '',
          );
      ref.invalidate(ratingEligibilityProvider(widget.sessionId));
      if (!mounted) return;
      final message = AppLocalizations.of(context).socialRatingSent;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.socialRateName(widget.name)),
      content: AppReactiveForm<void>(
        formGroup: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReactiveValueListenableBuilder<int>(
              formControlName: 'rating',
              builder: (context, control, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    key: Key('rating-star-${index + 1}'),
                    onPressed: _submitting
                        ? null
                        : () => control.value = index + 1,
                    icon: Icon(
                      AppIcons.star,
                      color: index < (control.value ?? 5)
                          ? Colors.amber.shade700
                          : Theme.of(context).disabledColor,
                    ),
                  ),
                ),
              ),
            ),
            ReactiveTextField<String>(
              formControlName: 'comment',
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(hintText: l10n.socialRatingComment),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.socialSendRating),
        ),
      ],
    );
  }
}
