import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/registration_controller.dart';
import 'package:vmito_app/features/auth/presentation/widgets/auth_status_panel.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _gender;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  static final _strongPassword = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = await ref
        .read(registrationControllerProvider.notifier)
        .submit(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          phone: _phoneController.text,
          gender: _gender,
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
    final state = ref.watch(registrationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignUpHeading)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.authSignUpHeading,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.authSignUpDescription,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
                          TextFormField(
                            key: const ValueKey('signup-name-field'),
                            controller: _nameController,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            enabled: !state.isLoading,
                            decoration: InputDecoration(
                              labelText: l10n.authSignUpName,
                              hintText: l10n.authSignUpNamePlaceholder,
                            ),
                            validator: (value) => value?.trim().isEmpty ?? true
                                ? l10n.authSignUpNameRequired
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const ValueKey('signup-email-field'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            enabled: !state.isLoading,
                            decoration: InputDecoration(
                              labelText: l10n.authSignUpEmail,
                              hintText: l10n.authSignUpEmailPlaceholder,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) {
                                return l10n.authSignUpEmailRequired;
                              }
                              if (!email.contains('@')) {
                                return l10n.authSignUpInvalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stacked = constraints.maxWidth < 360;
                              final phone = TextFormField(
                                key: const ValueKey('signup-phone-field'),
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber,
                                ],
                                textInputAction: TextInputAction.next,
                                maxLength: 10,
                                enabled: !state.isLoading,
                                decoration: InputDecoration(
                                  labelText: l10n.authSignUpPhone,
                                  hintText: l10n.authSignUpPhonePlaceholder,
                                  counterText: '',
                                ),
                                validator: (value) {
                                  final phone = value?.trim() ?? '';
                                  if (phone.isNotEmpty &&
                                      !RegExp(r'^\d{10}$').hasMatch(phone)) {
                                    return l10n.authSignUpPhoneInvalid;
                                  }
                                  return null;
                                },
                              );
                              final gender = DropdownButtonFormField<String>(
                                key: const ValueKey('signup-gender-field'),
                                initialValue: _gender,
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
                                onChanged: state.isLoading
                                    ? null
                                    : (value) =>
                                          setState(() => _gender = value),
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
                          TextFormField(
                            key: const ValueKey('signup-password-field'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.next,
                            enabled: !state.isLoading,
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
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) {
                                return l10n.authSignUpPasswordRequired;
                              }
                              if (password.length < 8 ||
                                  !_strongPassword.hasMatch(password)) {
                                return l10n.authSignUpPasswordWeak;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const ValueKey('signup-confirm-field'),
                            controller: _confirmController,
                            obscureText: _obscureConfirmation,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            enabled: !state.isLoading,
                            onFieldSubmitted: (_) =>
                                state.isLoading ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: l10n.authSignUpConfirmPassword,
                              hintText: l10n.authSignUpConfirmPlaceholder,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirmation =
                                      !_obscureConfirmation,
                                ),
                                icon: Icon(
                                  _obscureConfirmation
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return l10n.authSignUpConfirmRequired;
                              }
                              if (value != _passwordController.text) {
                                return l10n.authSignUpPasswordsDoNotMatch;
                              }
                              return null;
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
                          TextButton(
                            onPressed: state.isLoading
                                ? null
                                : () => context.go(AppRoutes.signIn),
                            child: Text(l10n.authSignUpAlreadyHaveAccount),
                          ),
                        ],
                      ),
                    ),
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
    if (error is ApiException) {
      if (error.statusCode == 429) return l10n.authTooManyRequests;
      if (error.statusCode == 409) return l10n.authSignUpUserExists;
      if (error.hasServerMessage) return error.message;
    }
    return l10n.authSignUpFailed;
  }
}
