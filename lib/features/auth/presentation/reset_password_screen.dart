import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/password_reset_controller.dart';
import 'package:vmito_app/features/auth/domain/password_reset.dart';
import 'package:vmito_app/features/auth/presentation/widgets/auth_status_panel.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(resetPasswordControllerProvider(widget.token).notifier)
        .submit(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final token = widget.token.trim();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authResetHeading)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.authResetHeading,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (token.isEmpty)
                        _InvalidTokenContent(
                          message: l10n.authResetMissingToken,
                        )
                      else
                        _VerifiedResetContent(
                          token: token,
                          formKey: _formKey,
                          passwordController: _passwordController,
                          confirmController: _confirmController,
                          obscurePassword: _obscurePassword,
                          obscureConfirmation: _obscureConfirmation,
                          onTogglePassword: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          onToggleConfirmation: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                          onSubmit: _submit,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifiedResetContent extends ConsumerWidget {
  const _VerifiedResetContent({
    required this.token,
    required this.formKey,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
    required this.onSubmit,
  });

  final String token;
  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final verification = ref.watch(passwordResetTokenProvider(token));

    return verification.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _InvalidTokenContent(
        message: l10n.authResetInvalidToken,
      ),
      data: (status) {
        if (!status.valid) {
          return _InvalidTokenContent(
            message: l10n.authResetInvalidToken,
          );
        }
        return _ResetForm(
          token: token,
          status: status,
          formKey: formKey,
          passwordController: passwordController,
          confirmController: confirmController,
          obscurePassword: obscurePassword,
          obscureConfirmation: obscureConfirmation,
          onTogglePassword: onTogglePassword,
          onToggleConfirmation: onToggleConfirmation,
          onSubmit: onSubmit,
        );
      },
    );
  }
}

class _ResetForm extends ConsumerWidget {
  const _ResetForm({
    required this.token,
    required this.status,
    required this.formKey,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
    required this.onSubmit,
  });

  final String token;
  final PasswordResetTokenStatus status;
  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resetPasswordControllerProvider(token));
    final completed = state.value ?? false;

    if (completed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusPanel(
            message: status.maskedEmail.isEmpty
                ? l10n.authResetSuccess
                : l10n.authResetSuccessWithEmail(status.maskedEmail),
            isError: false,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => context.go(AppRoutes.signIn),
            child: Text(l10n.authBackToSignIn),
          ),
        ],
      );
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            status.maskedEmail.isEmpty
                ? l10n.authResetDescription
                : l10n.authResetDescriptionWithEmail(status.maskedEmail),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (state.hasError) ...[
            AuthStatusPanel(
              message: _errorMessage(l10n, state.error),
              isError: true,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextFormField(
            key: const ValueKey('reset-password-field'),
            controller: passwordController,
            obscureText: obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            enabled: !state.isLoading,
            decoration: InputDecoration(
              labelText: l10n.authResetNewPassword,
              hintText: l10n.authResetNewPasswordPlaceholder,
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
            validator: (value) => (value?.length ?? 0) < 6
                ? l10n.authResetPasswordTooShort
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('reset-confirm-field'),
            controller: confirmController,
            obscureText: obscureConfirmation,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            enabled: !state.isLoading,
            onFieldSubmitted: (_) => state.isLoading ? null : onSubmit(),
            decoration: InputDecoration(
              labelText: l10n.authResetConfirmPassword,
              hintText: l10n.authResetConfirmPasswordPlaceholder,
              suffixIcon: IconButton(
                onPressed: onToggleConfirmation,
                icon: Icon(
                  obscureConfirmation
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return l10n.authResetConfirmRequired;
              }
              if (value != passwordController.text) {
                return l10n.authResetPasswordsDoNotMatch;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const ValueKey('reset-submit-button'),
            onPressed: state.isLoading ? null : onSubmit,
            child: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.authResetSubmit),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.go(AppRoutes.signIn),
            child: Text(l10n.authBackToSignIn),
          ),
        ],
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n, Object? error) {
    if (error is ApiException) {
      if (error.statusCode == 429) return l10n.authTooManyRequests;
      if (error.statusCode == 400 || error.statusCode == 401) {
        return l10n.authResetInvalidToken;
      }
    }
    return l10n.authResetFailed;
  }
}

class _InvalidTokenContent extends StatelessWidget {
  const _InvalidTokenContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthStatusPanel(message: message, isError: true),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => context.go(AppRoutes.signIn),
          child: Text(l10n.authBackToSignIn),
        ),
      ],
    );
  }
}
