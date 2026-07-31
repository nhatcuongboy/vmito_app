import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/password_reset_controller.dart';
import 'package:vmito_app/features/auth/presentation/widgets/auth_status_panel.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submit(
          email: _emailController.text,
          locale: Localizations.localeOf(context).languageCode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(forgotPasswordControllerProvider);
    final isSubmitted = state.value ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authForgotHeading)),
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
                        l10n.authForgotHeading,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.authForgotDescription,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (isSubmitted)
                        AuthStatusPanel(
                          message: l10n.authForgotSuccess,
                          isError: false,
                        )
                      else
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (state.hasError) ...[
                                AuthStatusPanel(
                                  message: _errorMessage(l10n, state.error),
                                  isError: true,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              TextFormField(
                                key: const ValueKey('forgot-email-field'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.done,
                                enabled: !state.isLoading,
                                onFieldSubmitted: (_) =>
                                    state.isLoading ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: l10n.authForgotEmail,
                                  hintText: l10n.authForgotEmailPlaceholder,
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return l10n.authForgotEmailRequired;
                                  }
                                  if (!email.contains('@')) {
                                    return l10n.authForgotInvalidEmail;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton(
                                key: const ValueKey('forgot-submit-button'),
                                onPressed: state.isLoading ? null : _submit,
                                child: state.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(l10n.authForgotSubmit),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.signIn),
                        child: Text(l10n.authBackToSignIn),
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

  String _errorMessage(AppLocalizations l10n, Object? error) {
    if (error is ApiException && error.statusCode == 429) {
      return l10n.authTooManyRequests;
    }
    return l10n.authForgotRequestFailed;
  }
}
