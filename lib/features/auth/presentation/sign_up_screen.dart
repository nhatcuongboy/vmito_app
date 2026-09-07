import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/registration_controller.dart';
import 'package:vmito_app/features/auth/presentation/widgets/auth_status_panel.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

abstract final class SignUpFormControl {
  static const name = 'name';
  static const email = 'email';
  static const phone = 'phone';
  static const gender = 'gender';
  static const password = 'password';
  static const confirmPassword = 'confirmPassword';
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  late final FormGroup _form;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _showPasswordRequirements = false;

  static final _strongPassword = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])',
  );

  static Map<String, dynamic>? _requiredTrimmed(
    AbstractControl<dynamic> control,
  ) {
    final value = control.value;
    if (value == null || (value is String && value.trim().isEmpty)) {
      return {ValidationMessage.required: true};
    }
    return null;
  }

  static Map<String, dynamic>? _emailValidator(
    AbstractControl<dynamic> control,
  ) {
    final raw = control.value as String?;
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final tempControl = FormControl<String>(value: value);
    return Validators.email(tempControl);
  }

  @override
  void initState() {
    super.initState();
    _form = FormGroup(
      {
        SignUpFormControl.name: FormControl<String>(
          validators: [Validators.delegate(_requiredTrimmed)],
        ),
        SignUpFormControl.email: FormControl<String>(
          validators: [
            Validators.delegate(_requiredTrimmed),
            Validators.delegate(_emailValidator),
          ],
        ),
        SignUpFormControl.phone: FormControl<String>(
          validators: [
            Validators.pattern(r'^\d{10}$'),
          ],
        ),
        SignUpFormControl.gender: FormControl<String>(),
        SignUpFormControl.password: FormControl<String>(
          validators: [
            Validators.required,
            Validators.minLength(8),
            Validators.delegate(_strongPasswordValidator),
          ],
        ),
        SignUpFormControl.confirmPassword: FormControl<String>(
          validators: [Validators.required],
        ),
      },
      validators: [
        Validators.mustMatch(
          SignUpFormControl.password,
          SignUpFormControl.confirmPassword,
        ),
      ],
    );
  }

  static Map<String, dynamic>? _strongPasswordValidator(
    AbstractControl<dynamic> control,
  ) {
    final value = control.value as String?;
    if (value == null || value.isEmpty) return null;
    return _strongPassword.hasMatch(value) ? null : {'weak': true};
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;

    final values = _form.value;
    final user = await ref
        .read(registrationControllerProvider.notifier)
        .submit(
          name: (values[SignUpFormControl.name]! as String).trim(),
          email: (values[SignUpFormControl.email]! as String).trim(),
          password: values[SignUpFormControl.password]! as String,
          phone: (values[SignUpFormControl.phone] as String?)?.trim(),
          gender: values[SignUpFormControl.gender] as String?,
          locale: Localizations.localeOf(context).languageCode,
        );
    if (user != null && mounted) {
      context.go('${AppRoutes.signIn}?registered=1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final state = ref.watch(registrationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignUpHeading)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppReactiveForm(
              formGroup: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.authSignUpTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.hasError) ...[
                    AuthStatusPanel(
                      message: _errorMessage(l10n, state.error),
                      isError: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    l10n.formRequiredUnlessOptional,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReactiveTextField<String>(
                    key: const ValueKey('signup-name-field'),
                    formControlName: SignUpFormControl.name,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    readOnly: state.isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.authSignUpName,
                      hintText: l10n.authSignUpNamePlaceholder,
                    ),
                    validationMessages: {
                      ValidationMessage.required: (_) =>
                          l10n.authSignUpNameRequired,
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReactiveTextField<String>(
                    key: const ValueKey('signup-email-field'),
                    formControlName: SignUpFormControl.email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    readOnly: state.isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.authSignUpEmail,
                      hintText: l10n.authSignUpEmailPlaceholder,
                    ),
                    validationMessages: {
                      ValidationMessage.required: (_) =>
                          l10n.authSignUpEmailRequired,
                      ValidationMessage.email: (_) =>
                          l10n.authSignUpInvalidEmail,
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.authSignUpOptionalDetails,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 360;
                      final phone = ReactiveTextField<String>(
                        key: const ValueKey('signup-phone-field'),
                        formControlName: SignUpFormControl.phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [
                          AutofillHints.telephoneNumber,
                        ],
                        textInputAction: TextInputAction.next,
                        maxLength: 10,
                        readOnly: state.isLoading,
                        decoration: InputDecoration(
                          labelText: l10n.authSignUpPhone,
                          hintText: l10n.authSignUpPhonePlaceholder,
                          counterText: '',
                        ),
                        validationMessages: {
                          ValidationMessage.pattern: (_) =>
                              l10n.authSignUpPhoneInvalid,
                        },
                      );
                      final gender = ReactiveDropdownField<String>(
                        key: const ValueKey('signup-gender-field'),
                        formControlName: SignUpFormControl.gender,
                        readOnly: state.isLoading,
                        decoration: InputDecoration(
                          labelText: l10n.authSignUpGender,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'MALE',
                            child: Text(l10n.authSignUpMale),
                          ),
                          DropdownMenuItem(
                            value: 'FEMALE',
                            child: Text(l10n.authSignUpFemale),
                          ),
                        ],
                      );

                      if (stacked) {
                        return Column(
                          children: [
                            phone,
                            const SizedBox(height: AppSpacing.md),
                            gender,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: phone),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: gender),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Focus(
                    onFocusChange: (hasFocus) {
                      setState(() => _showPasswordRequirements = hasFocus);
                    },
                    child: ReactiveTextField<String>(
                      key: const ValueKey('signup-password-field'),
                      formControlName: SignUpFormControl.password,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      readOnly: state.isLoading,
                      decoration: InputDecoration(
                        labelText: l10n.authSignUpPassword,
                        hintText: l10n.authSignUpPasswordPlaceholder,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword ? AppIcons.eyeOff : AppIcons.eye,
                          ),
                        ),
                      ),
                      validationMessages: {
                        ValidationMessage.required: (_) =>
                            l10n.authSignUpPasswordRequired,
                        ValidationMessage.minLength: (_) =>
                            l10n.authSignUpPasswordWeak,
                        'weak': (_) => l10n.authSignUpPasswordWeak,
                      },
                    ),
                  ),
                  if (_showPasswordRequirements) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        l10n.authSignUpPasswordRequirements,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  ReactiveTextField<String>(
                    key: const ValueKey('signup-confirm-field'),
                    formControlName: SignUpFormControl.confirmPassword,
                    obscureText: _obscureConfirmation,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    readOnly: state.isLoading,
                    onSubmitted: (_) => state.isLoading ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: l10n.authSignUpConfirmPassword,
                      hintText: l10n.authSignUpConfirmPlaceholder,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureConfirmation = !_obscureConfirmation,
                        ),
                        icon: Icon(
                          _obscureConfirmation ? AppIcons.eyeOff : AppIcons.eye,
                        ),
                      ),
                    ),
                    validationMessages: {
                      ValidationMessage.required: (_) =>
                          l10n.authSignUpConfirmRequired,
                      ValidationMessage.mustMatch: (_) =>
                          l10n.authSignUpPasswordsDoNotMatch,
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const ValueKey('signup-submit-button'),
                    onPressed: state.isLoading ? null : _submit,
                    child: state.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l10n.authSignUpCreateAccount),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.authAlreadyHaveAccount,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () => context.go(AppRoutes.signIn),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.authSignIn,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n, Object? error) {
    if (error is ApiException) {
      final msg = error.message.toLowerCase();
      if (error.statusCode == 429 || msg.contains('too many requests')) {
        return l10n.authTooManyRequests;
      }
      if (error.statusCode == 409 ||
          msg.contains('user already exists') ||
          msg.contains('already in use') ||
          msg.contains('already exists')) {
        return l10n.authSignUpUserExists;
      }
      if (error.hasServerMessage) return error.message;
    }
    return l10n.authSignUpFailed;
  }
}
