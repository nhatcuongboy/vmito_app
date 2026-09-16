import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/roster/domain/player_profile_draft.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_full_height_modal.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_domain/vmito_domain.dart';

Future<bool?> showPlayerProfileFormSheet(
  BuildContext context, {
  PlayerProfile? profile,
  String? defaultClubId,
  bool lockClubSelection = false,
}) {
  return showAppFullHeightModal<bool>(
    context,
    builder: (context) => _PlayerProfileFormSheet(
      profile: profile,
      defaultClubId: defaultClubId,
      lockClubSelection: lockClubSelection,
    ),
  );
}

class _PlayerProfileFormSheet extends ConsumerStatefulWidget {
  const _PlayerProfileFormSheet({
    this.profile,
    this.defaultClubId,
    this.lockClubSelection = false,
  });

  final PlayerProfile? profile;
  final String? defaultClubId;
  final bool lockClubSelection;

  @override
  ConsumerState<_PlayerProfileFormSheet> createState() =>
      _PlayerProfileFormSheetState();
}

class _PlayerProfileFormSheetState
    extends ConsumerState<_PlayerProfileFormSheet> {
  static const _nameControl = 'name';
  static const _genderControl = 'gender';
  static const _phoneControl = 'phone';
  static const _levelControl = 'level';
  static const _notesControl = 'notes';
  static const _clubIdControl = 'clubId';

  late final FormGroup _form;
  bool _submitting = false;

  bool get _isEditing => widget.profile != null;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _form = FormGroup({
      _nameControl: FormControl<String>(
        value: p?.name,
        validators: [Validators.required, Validators.maxLength(100)],
      ),
      _genderControl: FormControl<Gender>(
        value: p?.gender ?? Gender.male,
      ),
      _phoneControl: FormControl<String>(
        value: p?.phone,
      ),
      _levelControl: FormControl<int>(
        value: p?.level,
      ),
      _notesControl: FormControl<String>(
        value: p?.notes,
        validators: [Validators.maxLength(500)],
      ),
      _clubIdControl: FormControl<String>(
        value: p?.clubId ?? widget.defaultClubId,
      ),
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form
      ..markAllAsTouched()
      ..updateValueAndValidity();
    if (_form.invalid || _form.pending) return;

    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(rosterControllerProvider.notifier);

    final name = _form.control(_nameControl).value as String? ?? '';
    final gender = _form.control(_genderControl).value as Gender?;
    final phone = _form.control(_phoneControl).value as String?;
    final level = _form.control(_levelControl).value as int?;
    final notes = _form.control(_notesControl).value as String?;
    final clubId = _form.control(_clubIdControl).value as String?;

    bool success;
    if (_isEditing) {
      final draft = UpdatePlayerProfileDraft(
        name: name,
        gender: gender,
        phone: phone,
        level: level,
        notes: notes,
        clubId: clubId,
      );
      success = await controller.updateProfile(widget.profile!.id, draft);
    } else {
      final draft = CreatePlayerProfileDraft(
        name: name,
        gender: gender,
        phone: phone,
        level: level,
        notes: notes,
        clubId: clubId,
      );
      success = await controller.createProfile(draft);
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? l10n.rosterUpdateSuccess : l10n.rosterCreateSuccess,
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      final error = ref.read(rosterControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? l10n.errorUnknown),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final managedClubs = ref.watch(managedClubsProvider).asData?.value ?? [];

    return PopScope(
      canPop: !_submitting,
      child: AppReactiveForm<void>(
        formGroup: _form,
        child: Column(
          children: [
            AppSheetHeader(
              title: _isEditing
                  ? l10n.rosterEditProfileTitle
                  : l10n.rosterCreateProfileTitle,
              closeButtonEnabled: !_submitting,
              onClose: () => Navigator.pop(context, false),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  ReactiveTextField<String>(
                    formControlName: _nameControl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      label: AppRequiredLabel(l10n.rosterPlayerName),
                      hintText: l10n.rosterPlayerNameHint,
                    ),
                    validationMessages: {
                      ValidationMessage.required: (_) =>
                          l10n.rosterPlayerNameRequired,
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: ReactiveDropdownField<Gender>(
                          formControlName: _genderControl,
                          decoration: InputDecoration(
                            labelText: l10n.hostAddPlayerGender,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: Gender.male,
                              child: Text(l10n.genderMale),
                            ),
                            DropdownMenuItem(
                              value: Gender.female,
                              child: Text(l10n.genderFemale),
                            ),
                            DropdownMenuItem(
                              value: Gender.other,
                              child: Text(l10n.genderOther),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ReactiveDropdownField<int>(
                          formControlName: _levelControl,
                          decoration: InputDecoration(
                            labelText: l10n.registrationLevel,
                          ),
                          items: [
                            for (final lvl in validLevels)
                              DropdownMenuItem(
                                value: lvl,
                                child: Text(l10n.levelName(lvl)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReactiveTextField<String>(
                    formControlName: _phoneControl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.authSignUpPhone,
                      hintText: l10n.authSignUpPhonePlaceholder,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReactiveDropdownField<String>(
                    formControlName: _clubIdControl,
                    readOnly: widget.lockClubSelection,
                    decoration: InputDecoration(
                      labelText: l10n.rosterClubAssignment,
                      suffixIcon: widget.lockClubSelection
                          ? const Icon(Icons.lock_outline, size: 18)
                          : null,
                    ),
                    items: [
                      if (!widget.lockClubSelection)
                        DropdownMenuItem<String>(
                          child: Text(l10n.rosterPersonalBadge),
                        ),
                      for (final club in managedClubs)
                        DropdownMenuItem<String>(
                          value: club.id,
                          child: Text(club.name),
                        ),
                      if (widget.defaultClubId != null &&
                          !managedClubs.any((c) => c.id == widget.defaultClubId))
                        DropdownMenuItem<String>(
                          value: widget.defaultClubId,
                          child: Text(widget.defaultClubId!),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReactiveTextField<String>(
                    formControlName: _notesControl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.rosterNotesLabel,
                      hintText: l10n.rosterNotesHint,
                    ),
                  ),
                ],
              ),
            ),
            AppSheetActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context, false),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.commonSave),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
