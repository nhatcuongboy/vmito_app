import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/registration/domain/registration_player_draft.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// One player row of the registration form.
///
/// Ports the per-player card in
/// `vmito-fe/src/components/session/JoinSessionForm.tsx`.
class RegistrationPlayerCard extends StatelessWidget {
  const RegistrationPlayerCard({
    required this.draft,
    required this.levelOptions,
    required this.genderOptions,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final RegistrationPlayerDraft draft;

  /// Selectable levels, already in display-rank order. Restricted to the
  /// session's `requiredLevels` when it sets any — the web app filters the
  /// dropdown rather than warning after the fact, and so does this.
  final List<int> levelOptions;

  /// Restricted to male/female when the session prices by gender, since the
  /// fee calculation has no bucket for the others.
  final List<Gender> genderOptions;

  final ValueChanged<RegistrationPlayerDraft> onChanged;

  /// Null for the "me" row, which cannot be removed.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoleBadge(isMe: draft.isMe),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  tooltip: l10n.registrationRemoveGuest,
                  icon: const Icon(AppIcons.delete, size: 20),
                  color: theme.colorScheme.error,
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: draft.name,
            decoration: InputDecoration(
              labelText: l10n.authSignUpName,
              isDense: true,
            ),
            textInputAction: TextInputAction.next,
            validator: (value) => (value ?? '').trim().isEmpty
                ? l10n.registrationNameRequired
                : null,
            onChanged: (value) => onChanged(draft.copyWith(name: value)),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          TextFormField(
            initialValue: draft.phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.authSignUpPhone,
              isDense: true,
            ),
            // Optional and unvalidated, same as web — a host can chase a
            // player without it, and a format rule here would only block
            // legitimate numbers.
            onChanged: (value) => onChanged(draft.copyWith(phone: value)),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Gender>(
                  initialValue: draft.gender,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.authSignUpGender,
                    isDense: true,
                  ),
                  items: [
                    for (final gender in genderOptions)
                      DropdownMenuItem(
                        value: gender,
                        child: Text(_genderLabel(l10n, gender)),
                      ),
                  ],
                  onChanged: (value) => value == null
                      ? null
                      : onChanged(draft.copyWith(gender: value)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: draft.level,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.registrationLevel,
                    hintText: l10n.registrationLevelHint,
                    isDense: true,
                  ),
                  items: [
                    for (final level in levelOptions)
                      DropdownMenuItem(
                        value: level,
                        child: Text(l10n.levelName(level)),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? l10n.registrationLevelRequired : null,
                  onChanged: (value) => value == null
                      ? null
                      : onChanged(draft.copyWith(level: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          TextFormField(
            initialValue: draft.levelDescription,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.registrationLevelDescription,
              hintText: l10n.registrationLevelDescriptionHint,
              isDense: true,
            ),
            onChanged: (value) =>
                onChanged(draft.copyWith(levelDescription: value)),
          ),
        ],
      ),
    );
  }

  static String _genderLabel(AppLocalizations l10n, Gender gender) =>
      switch (gender) {
        Gender.male => l10n.authSignUpMale,
        Gender.female => l10n.authSignUpFemale,
        Gender.other => l10n.registrationGenderOther,
      };
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isMe});

  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final color = isMe ? theme.colorScheme.primary : palette.info;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.profile, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isMe ? l10n.registrationYou : l10n.registrationGuest,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
