import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/profile/application/profile_controller.dart';
import 'package:vmito_app/features/profile/domain/form/profile_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_domain/vmito_domain.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final details = ref.watch(profileDetailsProvider(currentUser.id));
    return details.when(
      data: (user) => _EditProfileForm(key: ValueKey(user.id), user: user),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(profileDetailsProvider(currentUser.id)),
        ),
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.user, super.key});

  final User user;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  late final FormGroup _form = createProfileForm(
    name: widget.user.name ?? '',
    email: widget.user.email,
    phone: widget.user.phone,
    gender: widget.user.gender,
    level: widget.user.level,
    levelDescription: widget.user.levelDescription,
  );

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(widget.user.id, ProfileDraft.fromForm(_form));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? l10n.profileUpdateSuccess : l10n.profileUpdateFailed,
        ),
      ),
    );
    if (success) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saving = ref.watch(profileControllerProvider).isSaving;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileEditTitle)),
      body: SafeArea(
        top: false,
        child: ReactiveForm(
          formGroup: _form,
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    ReactiveTextField<String>(
                      key: const ValueKey('profile-name-field'),
                      formControlName: ProfileFormControl.name,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      readOnly: saving,
                      decoration: InputDecoration(
                        label: AppRequiredLabel(l10n.profileName),
                      ),
                      validationMessages: {
                        ValidationMessage.required: (_) =>
                            l10n.profileNameRequired,
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReactiveTextField<String>(
                      key: const ValueKey('profile-email-field'),
                      formControlName: ProfileFormControl.email,
                      decoration: InputDecoration(
                        labelText: l10n.profileEmail,
                        prefixIcon: const Icon(AppIcons.lock),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (constraints.maxWidth >= 600)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _phoneField(l10n, saving)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: _genderField(l10n, saving)),
                        ],
                      )
                    else ...[
                      _phoneField(l10n, saving),
                      const SizedBox(height: AppSpacing.md),
                      _genderField(l10n, saving),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    ReactiveDropdownField<int>(
                      key: const ValueKey('profile-level-field'),
                      formControlName: ProfileFormControl.level,
                      readOnly: saving,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.profileLevel,
                      ),
                      items: [
                        DropdownMenuItem<int>(
                          child: Text(l10n.profileSelectLevel),
                        ),
                        for (final level in validLevels)
                          DropdownMenuItem<int>(
                            value: level,
                            child: Text(l10n.levelName(level)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReactiveTextField<String>(
                      key: const ValueKey('profile-level-description-field'),
                      formControlName: ProfileFormControl.levelDescription,
                      readOnly: saving,
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: l10n.profileLevelDescription,
                        hintText: l10n.profileLevelDescriptionHint,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      key: const ValueKey('profile-change-password-button'),
                      onPressed: saving
                          ? null
                          : () => context.pushNamed(
                              AppRoutes.nameChangePassword,
                            ),
                      icon: const Icon(AppIcons.lock),
                      label: Text(l10n.profileChangePassword),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      key: const ValueKey('profile-save-button'),
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
      ),
    );
  }

  Widget _phoneField(AppLocalizations l10n, bool saving) =>
      ReactiveTextField<String>(
        key: const ValueKey('profile-phone-field'),
        formControlName: ProfileFormControl.phone,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        textInputAction: TextInputAction.next,
        readOnly: saving,
        decoration: InputDecoration(labelText: l10n.profilePhone),
      );

  Widget _genderField(AppLocalizations l10n, bool saving) =>
      ReactiveDropdownField<String>(
        key: const ValueKey('profile-gender-field'),
        formControlName: ProfileFormControl.gender,
        readOnly: saving,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.profileGender),
        items: [
          DropdownMenuItem<String>(child: Text(l10n.profileSelectGender)),
          DropdownMenuItem(value: 'MALE', child: Text(l10n.profileGenderMale)),
          DropdownMenuItem(
            value: 'FEMALE',
            child: Text(l10n.profileGenderFemale),
          ),
          DropdownMenuItem(
            value: 'OTHER',
            child: Text(l10n.profileGenderOther),
          ),
          DropdownMenuItem(
            value: 'PREFER_NOT_TO_SAY',
            child: Text(l10n.profileGenderPreferNotToSay),
          ),
        ],
      );
}
