import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/oauth_provider.dart';
import 'package:vmito_app/features/auth/presentation/widgets/apple_sign_in_button.dart';
import 'package:vmito_app/features/auth/presentation/widgets/auth_status_panel.dart';
import 'package:vmito_app/features/auth/presentation/widgets/oauth_sign_in_button.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Email/password sign-in — the reference screen for this codebase.
///
/// Shows the expected shape: `ConsumerStatefulWidget` for local form state,
/// a controller call for the mutation, `ApiException` caught and rendered
/// inline (the service passes `skipGlobalError`), and every string localised.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({this.registrationCompleted = false, super.key});

  final bool registrationCompleted;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

abstract final class SignInFormControl {
  static const identifier = 'identifier';
  static const password = 'password';
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final FormGroup _form;

  bool _isSubmitting = false;
  OAuthProvider? _oauthProvider;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isBusy => _isSubmitting || _oauthProvider != null;

  static final _phoneNumber = RegExp(r'^\+?[0-9][0-9 .-]{7,}$');

  @override
  void initState() {
    super.initState();
    _form = FormGroup({
      SignInFormControl.identifier: FormControl<String>(
        validators: [Validators.required, Validators.delegate(_emailOrPhone)],
      ),
      SignInFormControl.password: FormControl<String>(
        validators: [Validators.required],
      ),
    });
  }

  static Map<String, dynamic>? _emailOrPhone(
    AbstractControl<dynamic> control,
  ) {
    final value = (control.value as String?)?.trim() ?? '';
    if (value.isEmpty ||
        Validators.email(control) == null ||
        _phoneNumber.hasMatch(value)) {
      return null;
    }
    return {'emailOrPhone': true};
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending || _isBusy) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: (_form.control(SignInFormControl.identifier).value as String)
                .trim(),
            password: _form.control(SignInFormControl.password).value as String,
          );
      // No manual navigation: the router redirect reacts to auth status.
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    setState(() {
      _oauthProvider = provider;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithOAuth(
            provider: provider,
            locale: Localizations.localeOf(context).languageCode,
          );
      // Router redirect reacts to the authenticated state.
    } on PlatformException catch (error) {
      // Closing the provider tab is an ordinary choice, not an error banner.
      if (error.code != 'CANCELED' && mounted) {
        AppLogger.warn('OAuth platform flow failed', error: error);
        setState(
          () => _errorMessage = AppLocalizations.of(context).authSocialFailed,
        );
      }
    } on ApiException catch (error) {
      AppLogger.warn('OAuth callback was rejected', error: error);
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context).authSocialFailed,
        );
      }
    } on Object catch (error) {
      AppLogger.warn('OAuth sign-in failed', error: error);
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context).authSocialFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _oauthProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.home),
          onPressed: () => context.go(AppRoutes.home),
          tooltip: l10n.navHome,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ReactiveForm(
                formGroup: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/icons/logo-show.png',
                      height: 78,
                      fit: BoxFit.contain,
                      semanticLabel: l10n.appName,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    ReactiveTextField<String>(
                      key: const ValueKey('signin-identifier-field'),
                      formControlName: SignInFormControl.identifier,
                      keyboardType: TextInputType.text,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.telephoneNumber,
                      ],
                      textInputAction: TextInputAction.next,
                      readOnly: _isBusy,
                      decoration: InputDecoration(
                        labelText: l10n.authEmail,
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                      ),
                      validationMessages: {
                        ValidationMessage.required: (_) =>
                            l10n.authEmailOrPhoneRequired,
                        'emailOrPhone': (_) => l10n.authEmailOrPhoneInvalid,
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    ReactiveTextField<String>(
                      key: const ValueKey('signin-password-field'),
                      formControlName: SignInFormControl.password,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      // Guarded like the button: without this, hitting "done"
                      // on the keyboard while a request is in flight fires a
                      // second login. /auth/login allows 5 per minute, so a
                      // double submit spends the user's allowance twice as
                      // fast. Caught by the on-device integration test.
                      onSubmitted: (_) => _isBusy ? null : _submit(),
                      readOnly: _isBusy,
                      decoration: InputDecoration(
                        labelText: l10n.authPassword,
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? AppIcons.eyeOff : AppIcons.eye,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validationMessages: {
                        ValidationMessage.required: (_) =>
                            l10n.authPasswordRequired,
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isBusy
                            ? null
                            : () => context.push(AppRoutes.forgotPassword),
                        child: Text(l10n.authForgotPassword),
                      ),
                    ),

                    if (widget.registrationCompleted) ...[
                      const SizedBox(height: AppSpacing.md),
                      AuthStatusPanel(
                        message: l10n.authSignUpAccountCreated,
                        isError: false,
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      key: const ValueKey('signin-submit-button'),
                      onPressed: _isBusy ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.authSignIn),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: Text(
                            l10n.authOr,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OAuthSignInButton(
                          provider: OAuthProvider.google,
                          label: l10n.authContinueWithGoogle,
                          enabled: !_isBusy,
                          isLoading: _oauthProvider == OAuthProvider.google,
                          onPressed: () =>
                              _signInWithOAuth(OAuthProvider.google),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        OAuthSignInButton(
                          provider: OAuthProvider.facebook,
                          label: l10n.authContinueWithFacebook,
                          enabled: !_isBusy,
                          isLoading: _oauthProvider == OAuthProvider.facebook,
                          onPressed: () =>
                              _signInWithOAuth(OAuthProvider.facebook),
                        ),
                        // Guideline 4.8 requires Sign in with Apple to be no
                        // less prominent than the other social options.
                        if (AppleSignInButton.isSupported) ...[
                          const SizedBox(width: AppSpacing.md),
                          AppleSignInButton(
                            enabled: !_isBusy,
                            onError: (message) =>
                                setState(() => _errorMessage = message),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: Text(l10n.authNoAccount)),
                        TextButton(
                          onPressed: _isBusy
                              ? null
                              : () => context.push(AppRoutes.signUp),
                          child: Text(l10n.authSignUp),
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
}
