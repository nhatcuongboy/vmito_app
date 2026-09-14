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
import 'package:vmito_app/features/auth/domain/form/sign_up_form.dart';
import 'package:vmito_app/features/auth/presentation/widgets/auth_status_panel.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  late final FormGroup _form;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _form = createSignUpForm();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _hasSubmitted = true);
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppReactiveForm<void>(
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
                    ReactiveTextField<String>(
                      key: const ValueKey('signup-password-field'),
                      formControlName: SignUpFormControl.password,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      readOnly: state.isLoading,
                      decoration: InputDecoration(
                        labelText: l10n.authSignUpPassword,
                        hintText: l10n.authSignUpPasswordPlaceholder,
                        helperText: l10n.authSignUpPasswordRequirements,
                        helperMaxLines: 2,
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
                    const SizedBox(height: AppSpacing.md),
                    ReactiveTextField<String>(
                      key: const ValueKey('signup-confirm-field'),
                      formControlName: SignUpFormControl.confirmPassword,
                      obscureText: _obscureConfirmation,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      readOnly: state.isLoading,
                      decoration: InputDecoration(
                        labelText: l10n.authSignUpConfirmPassword,
                        hintText: l10n.authSignUpConfirmPlaceholder,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                          icon: Icon(
                            _obscureConfirmation
                                ? AppIcons.eyeOff
                                : AppIcons.eye,
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
                    Semantics(
                      header: true,
                      label:
                          '${l10n.authSignUpAdditionalDetails}, ${l10n.formOptional}',
                      child: ExcludeSemantics(
                        child: Row(
                          key: const ValueKey(
                            'signup-optional-details-heading',
                          ),
                          children: [
                            Expanded(
                              child: Text(
                                l10n.authSignUpAdditionalDetails,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              l10n.formOptional,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: palette.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReactiveTextField<String>(
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
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReactiveDropdownField<String>(
                      key: const ValueKey('signup-gender-field'),
                      formControlName: SignUpFormControl.gender,
                      readOnly: state.isLoading,
                      decoration: InputDecoration(
                        labelText: l10n.authSignUpGender,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'MALE',
                          child: Text(
                            l10n.authSignUpMale,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'FEMALE',
                          child: Text(
                            l10n.authSignUpFemale,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // A GestureDetector (not CheckboxListTile) around a
                    // top-aligned Row: CheckboxListTile always centers its
                    // leading widget against the full title height, and this
                    // label needs the checkbox pinned to the first line
                    // instead. The outer tap target covers the whole
                    // sentence — tapping anywhere toggles the checkbox — so
                    // ReactiveCheckbox can stay shrink-wrapped and hug the
                    // text. The two inline links stay above it in the
                    // hit-test tree, so taps on them resolve to the link, not
                    // the toggle.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final control =
                            _form.control(SignUpFormControl.acceptedTerms)
                                as FormControl<bool>;
                        final next = !(control.value ?? false);
                        control
                          ..markAsTouched()
                          ..updateValue(next);
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          ReactiveCheckbox(
                            key: const ValueKey('signup-terms-checkbox'),
                            formControlName: SignUpFormControl.acceptedTerms,
                            activeColor: theme.colorScheme.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.65),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(text: l10n.authSignUpTermsPrefix),
                                  WidgetSpan(
                                    child: _TermsLinkButton(
                                      label: l10n.legalTermsTab,
                                      onPressed: () => context.push(AppRoutes.terms),
                                    ),
                                  ),
                                  TextSpan(
                                    text: l10n.authSignUpTermsConnector,
                                  ),
                                  WidgetSpan(
                                    child: _TermsLinkButton(
                                      label: l10n.legalPrivacyTab,
                                      onPressed: () =>
                                          context.push(AppRoutes.privacy),
                                    ),
                                  ),
                                  TextSpan(text: l10n.authSignUpTermsSuffix),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((_hasSubmitted ||
                            _form
                                .control(SignUpFormControl.acceptedTerms)
                                .touched) &&
                        _form
                            .control(SignUpFormControl.acceptedTerms)
                            .hasError(
                              ValidationMessage.requiredTrue,
                            ))
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          left: 28,
                        ),
                        child: Text(
                          l10n.authSignUpTermsRequired,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
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

/// An inline "Terms of Service" / "Privacy Policy" link embedded via
/// [WidgetSpan] in the terms-agreement sentence. Underlined on top of the
/// bold primary color so it still reads as a link now that there's no
/// separate "View terms" affordance pointing at it.
class _TermsLinkButton extends StatelessWidget {
  const _TermsLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        _lowercaseFirstLetter(label),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: primary,
          decoration: TextDecoration.underline,
          decorationColor: primary,
        ),
      ),
    );
  }

  String _lowercaseFirstLetter(String value) {
    if (value.isEmpty) return value;
    final first = value.substring(0, 1);
    return '${first.toLowerCase()}${value.substring(1)}';
  }
}
