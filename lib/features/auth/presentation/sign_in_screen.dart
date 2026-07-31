import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
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

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  OAuthProvider? _oauthProvider;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isBusy => _isSubmitting || _oauthProvider != null;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l10n.authEmail),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return l10n.authEmailRequired;
                        if (!email.contains('@')) return l10n.authEmailInvalid;
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      // Guarded like the button: without this, hitting "done"
                      // on the keyboard while a request is in flight fires a
                      // second login. /auth/login allows 5 per minute, so a
                      // double submit spends the user's allowance twice as
                      // fast. Caught by the on-device integration test.
                      onFieldSubmitted: (_) => _isBusy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.authPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? l10n.authPasswordRequired
                          : null,
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

                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _isBusy ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.authSignIn),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => context.push(AppRoutes.forgotPassword),
                      child: Text(l10n.authForgotPassword),
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
                    OAuthSignInButton(
                      provider: OAuthProvider.google,
                      label: l10n.authContinueWithGoogle,
                      enabled: !_isBusy,
                      isLoading: _oauthProvider == OAuthProvider.google,
                      onPressed: () => _signInWithOAuth(OAuthProvider.google),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OAuthSignInButton(
                      provider: OAuthProvider.facebook,
                      label: l10n.authContinueWithFacebook,
                      enabled: !_isBusy,
                      isLoading: _oauthProvider == OAuthProvider.facebook,
                      onPressed: () => _signInWithOAuth(
                        OAuthProvider.facebook,
                      ),
                    ),

                    // Guideline 4.8 requires Sign in with Apple to be no less
                    // prominent than Google/Facebook on Apple platforms.
                    if (AppleSignInButton.isSupported) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppleSignInButton(
                        enabled: !_isBusy,
                        onError: (message) =>
                            setState(() => _errorMessage = message),
                      ),
                    ],
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
