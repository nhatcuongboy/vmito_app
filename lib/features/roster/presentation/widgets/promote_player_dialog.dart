import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/roster/domain/player_profile_draft.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

Future<bool?> showPromotePlayerDialog(
  BuildContext context, {
  required PlayerProfile profile,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _PromotePlayerDialog(profile: profile),
  );
}

class _PromotePlayerDialog extends ConsumerStatefulWidget {
  const _PromotePlayerDialog({required this.profile});

  final PlayerProfile profile;

  @override
  ConsumerState<_PromotePlayerDialog> createState() =>
      _PromotePlayerDialogState();
}

class _PromotePlayerDialogState extends ConsumerState<_PromotePlayerDialog> {
  static const _emailControl = 'email';
  static const _passwordControl = 'password';
  static const _nameControl = 'name';

  late final FormGroup _form;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _form = FormGroup({
      _emailControl: FormControl<String>(
        validators: [Validators.required, Validators.email],
      ),
      _passwordControl: FormControl<String>(
        validators: [Validators.required, Validators.minLength(6)],
      ),
      _nameControl: FormControl<String>(
        value: widget.profile.name,
        validators: [Validators.required],
      ),
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form
      ..markAllAsTouched()
      ..updateValueAndValidity();
    if (_form.invalid || _form.pending) return;

    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(rosterControllerProvider.notifier);

    final email = _form.control(_emailControl).value as String? ?? '';
    final password = _form.control(_passwordControl).value as String? ?? '';
    final name = _form.control(_nameControl).value as String?;

    final draft = PromoteProfileDraft(
      email: email,
      password: password,
      name: name,
    );

    final success =
        await controller.promoteProfile(widget.profile.id, draft);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.pop(context, true);
      await showAppConfirmDialog(
        context,
        title: l10n.rosterPromoteSuccessTitle,
        content: l10n.rosterPromoteSuccessMessage,
        confirmLabel: l10n.commonDone,
      );
    } else {
      final error = ref.read(rosterControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? l10n.errorUnknown),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.arrow_circle_up_rounded,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(l10n.rosterPromoteToUserTitle)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: AppReactiveForm<void>(
          formGroup: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.rosterPromoteExplanation,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ReactiveTextField<String>(
                  formControlName: _emailControl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    label: AppRequiredLabel(l10n.authEmail),
                    hintText: l10n.authSignUpEmailPlaceholder,
                  ),
                  validationMessages: {
                    ValidationMessage.required: (_) =>
                        l10n.authSignUpEmailRequired,
                    ValidationMessage.email: (_) => l10n.authSignUpInvalidEmail,
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveTextField<String>(
                  formControlName: _passwordControl,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    label: AppRequiredLabel(l10n.authPassword),
                    hintText: l10n.rosterPromotePasswordHint,
                  ),
                  validationMessages: {
                    ValidationMessage.required: (_) =>
                        l10n.authSignUpPasswordRequired,
                    ValidationMessage.minLength: (_) =>
                        l10n.rosterPromotePasswordMinLength,
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveTextField<String>(
                  formControlName: _nameControl,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    label: AppRequiredLabel(l10n.authSignUpName),
                  ),
                  validationMessages: {
                    ValidationMessage.required: (_) =>
                        l10n.authSignUpNameRequired,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.rosterPromoteConfirmAction),
        ),
      ],
    );
  }
}
