import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/core/widgets/app_logo.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
import 'package:vmito_app/core/widgets/theme_mode_selector.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/application/biometric_sign_in_provider.dart';
import 'package:vmito_app/features/auth/domain/oauth_provider.dart';
import 'package:vmito_app/features/auth/presentation/widgets/apple_sign_in_button.dart';
import 'package:vmito_app/features/auth/presentation/widgets/auth_status_panel.dart';
import 'package:vmito_app/features/auth/presentation/widgets/biometric_sign_in.dart';
import 'package:vmito_app/features/auth/presentation/widgets/oauth_sign_in_button.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// Email/password sign-in — the reference screen for this codebase.
///
/// Shows the expected shape: `ConsumerStatefulWidget` for local form state,
/// a controller call for the mutation, `ApiException` caught and rendered
/// inline (the service passes `skipGlobalError`), and every string localised.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    this.registrationCompleted = false,
    this.redirect,
    super.key,
  });

  final bool registrationCompleted;
  final String? redirect;

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
  bool _isBiometricSigningIn = false;
  String? _errorMessage;

  bool get _isBusy =>
      _isSubmitting || _oauthProvider != null || _isBiometricSigningIn;

  static Map<String, dynamic>? _requiredTrimmed(
    AbstractControl<dynamic> control,
  ) {
    final value = control.value;
    if (value == null || (value is String && value.trim().isEmpty)) {
      return {ValidationMessage.required: true};
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _form = FormGroup({
      SignInFormControl.identifier: FormControl<String>(
        validators: [
          Validators.delegate(_requiredTrimmed),
          Validators.email,
        ],
      ),
      SignInFormControl.password: FormControl<String>(
        validators: [Validators.delegate(_requiredTrimmed)],
      ),
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  String _mapErrorMessage(AppLocalizations l10n, ApiException error) {
    final rawError = error.message.toLowerCase();
    if (error.statusCode == 429 || rawError.contains('too many requests')) {
      return l10n.authTooManyRequests;
    }
    if (error.statusCode == 401 ||
        rawError.contains('invalid credentials') ||
        rawError.contains('invalid email or password')) {
      return l10n.authInvalidCredentials;
    }
    if (error.hasServerMessage) {
      return error.message;
    }
    return l10n.authSignInFailed;
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
      _goAfterSignIn();
    } on ApiException catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _errorMessage = _mapErrorMessage(l10n, error));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// The Face ID / fingerprint shortcut: device check first, then the token
  /// exchange. A failed device check never reaches the network.
  Future<void> _signInWithBiometrics() async {
    if (_isBusy) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isBiometricSigningIn = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(biometricAuthenticatorProvider)
          .authenticate(reason: l10n.biometricSignInReason);
      if (!result.authenticated) {
        if (mounted) {
          setState(
            () => _errorMessage = switch (result.failure) {
              BiometricAuthFailure.canceled => null,
              BiometricAuthFailure.unavailable =>
                l10n.biometricUnavailableError,
              BiometricAuthFailure.lockedOut => l10n.biometricLockedOutError,
              BiometricAuthFailure.failed || null => l10n.biometricFailedError,
            },
          );
        }
        return;
      }

      await ref.read(authControllerProvider.notifier).signInWithBiometrics();
      _goAfterSignIn();
    } on ApiException catch (error) {
      AppLogger.warn('biometric sign-in failed', error: error);
      if (mounted) {
        setState(
          () => _errorMessage = error.isUnauthorized
              ? l10n.biometricSignInExpired
              : _mapErrorMessage(l10n, error),
        );
      }
      ref.invalidate(biometricSignInOfferProvider);
    } finally {
      if (mounted) setState(() => _isBiometricSigningIn = false);
    }
  }

  /// "Switch account" — drops the saved session so the shortcut disappears
  /// and the next sign-in starts from a blank form.
  Future<void> _forgetBiometricAccount() async {
    await ref.read(authControllerProvider.notifier).forgetBiometricSignIn();
    ref.invalidate(biometricSignInOfferProvider);
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
      _goAfterSignIn();
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

  void _goAfterSignIn() {
    final redirect = widget.redirect;
    if (!mounted || redirect == null || redirect.isEmpty) return;
    context.go(redirect.startsWith('/') ? redirect : AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final biometricOffer = ref.watch(biometricSignInOfferProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.home),
          onPressed: () => context.go(AppRoutes.home),
          tooltip: l10n.navHome,
        ),
        actions: const [
          LanguageButton(),
          ThemeModeButton(),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          // Align(topCenter) instead of Center: centers the form horizontally
          // without vertically centering short content in the viewport,
          // which was pushing the logo far down the screen on tall devices.
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppReactiveForm<Object>(
                formGroup: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: AppLogo(
                        height: 85,
                        axis: Axis.vertical,
                        vmitoFontSize: 48,
                        sloganFontSize: 13,
                        semanticLabel: l10n.appName,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (biometricOffer != null) ...[
                      BiometricAccountCard(
                        offer: biometricOffer,
                        onSwitchAccount: _isBusy
                            ? null
                            : _forgetBiometricAccount,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    ReactiveTextField<String>(
                      key: const ValueKey('signin-identifier-field'),
                      formControlName: SignInFormControl.identifier,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      readOnly: _isBusy,
                      decoration: InputDecoration(
                        labelText: l10n.authEmail,
                      ),
                      validationMessages: {
                        ValidationMessage.required: (_) =>
                            l10n.authEmailRequired,
                        ValidationMessage.email: (_) => l10n.authEmailInvalid,
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
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (biometricOffer != null)
                              BiometricSignInButton(
                                kind: biometricOffer.kind,
                                onPressed: _isBusy
                                    ? null
                                    : _signInWithBiometrics,
                              ),
                            IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? AppIcons.eyeOff
                                    : AppIcons.eye,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ],
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
                    if (biometricOffer != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        key: const ValueKey('signin-biometric-action'),
                        onPressed: _isBusy ? null : _signInWithBiometrics,
                        icon: _isBiometricSigningIn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                biometricOffer.kind == BiometricKind.fingerprint
                                    ? AppIcons.fingerprint
                                    : AppIcons.biometric,
                              ),
                        label: Text(
                          biometricSignInLabel(l10n, biometricOffer.kind),
                        ),
                      ),
                    ],
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
