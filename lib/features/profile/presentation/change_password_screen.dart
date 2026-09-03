import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/profile/application/profile_controller.dart';
import 'package:vmito_app/features/profile/domain/form/profile_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final FormGroup _form = createChangePasswordForm();
  var _obscureCurrent = true;
  var _obscureNew = true;
  var _obscureConfirmation = true;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    final success = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(
          currentPassword:
              _form.control(ChangePasswordFormControl.currentPassword).value!
                  as String,
          newPassword:
              _form.control(ChangePasswordFormControl.newPassword).value!
                  as String,
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? l10n.profilePasswordChanged
              : l10n.profilePasswordChangeFailed,
        ),
      ),
    );
    if (success) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saving = ref.watch(changePasswordControllerProvider).isSaving;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileChangePassword)),
      body: SafeArea(
        top: false,
        child: AppReactiveForm(
          formGroup: _form,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _passwordField(
                    key: const ValueKey('current-password-field'),
                    controlName: ChangePasswordFormControl.currentPassword,
                    label: l10n.profileCurrentPassword,
                    obscure: _obscureCurrent,
                    saving: saving,
                    toggle: () => setState(
                      () => _obscureCurrent = !_obscureCurrent,
                    ),
                    requiredMessage: l10n.profilePasswordRequired,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _passwordField(
                    key: const ValueKey('new-password-field'),
                    controlName: ChangePasswordFormControl.newPassword,
                    label: l10n.profileNewPassword,
                    obscure: _obscureNew,
                    saving: saving,
                    toggle: () => setState(() => _obscureNew = !_obscureNew),
                    requiredMessage: l10n.profilePasswordRequired,
                    weakMessage: l10n.profilePasswordWeak,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _passwordField(
                    key: const ValueKey('confirm-password-field'),
                    controlName: ChangePasswordFormControl.confirmPassword,
                    label: l10n.profileConfirmPassword,
                    obscure: _obscureConfirmation,
                    saving: saving,
                    toggle: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                    requiredMessage: l10n.profilePasswordRequired,
                    mismatchMessage: l10n.profilePasswordsDoNotMatch,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const ValueKey('change-password-submit-button'),
                    onPressed: saving ? null : _submit,
                    child: saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.commonSave),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required Key key,
    required String controlName,
    required String label,
    required bool obscure,
    required bool saving,
    required VoidCallback toggle,
    required String requiredMessage,
    String? weakMessage,
    String? mismatchMessage,
  }) => ReactiveTextField<String>(
    key: key,
    formControlName: controlName,
    obscureText: obscure,
    readOnly: saving,
    autofillHints: const [AutofillHints.newPassword],
    textInputAction: controlName == ChangePasswordFormControl.confirmPassword
        ? TextInputAction.done
        : TextInputAction.next,
    onSubmitted: controlName == ChangePasswordFormControl.confirmPassword
        ? (_) => saving ? null : _submit()
        : null,
    decoration: InputDecoration(
      label: AppRequiredLabel(label),
      suffixIcon: IconButton(
        onPressed: saving ? null : toggle,
        icon: Icon(obscure ? AppIcons.eyeOff : AppIcons.eye),
      ),
    ),
    validationMessages: {
      ValidationMessage.required: (_) => requiredMessage,
      if (weakMessage != null) ValidationMessage.minLength: (_) => weakMessage,
      if (weakMessage != null) 'weak': (_) => weakMessage,
      if (mismatchMessage != null)
        ValidationMessage.mustMatch: (_) => mismatchMessage,
    },
  );
}
