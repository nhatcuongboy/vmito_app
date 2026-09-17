import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session_hosting/application/host_add_players_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

class HostPlayerForm extends StatelessWidget {
  const HostPlayerForm({
    required this.index,
    required this.number,
    required this.levels,
    required this.state,
    required this.canRemove,
    required this.onRemove,
    required this.onPickPlayer,
    this.nameFocusNode,
    this.canPickExistingPlayer = true,
    this.canSaveToRoster = true,
    this.showSaveToRosterWhenLinked = false,
    super.key,
  });

  final int index;
  final int number;
  final List<int> levels;
  final HostAddPlayersState state;
  final bool canRemove;
  final FocusNode? nameFocusNode;
  final VoidCallback onRemove;
  final VoidCallback? onPickPlayer;
  final bool canPickExistingPlayer;
  final bool canSaveToRoster;
  final bool showSaveToRosterWhenLinked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Chip(label: Text('#$number')),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    key: ValueKey('host-remove-player-$index'),
                    tooltip: l10n.hostAddPlayerRemove,
                    color: theme.colorScheme.error,
                    onPressed: onRemove,
                    icon: const Icon(AppIcons.delete),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: ValueKey('host-player-user-$index'),
              onPressed: canPickExistingPlayer ? onPickPlayer : null,
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                side: BorderSide(color: theme.dividerColor),
              ),
              icon: Icon(
                AppIcons.search,
                color: canPickExistingPlayer
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.disabledColor,
              ),
              label: ReactiveFormConsumer(
                builder: (context, form, _) {
                  final name =
                      form.control(HostPlayerFormControl.name).value as String?;
                  final hasLinked =
                      (form.control(HostPlayerFormControl.userId).value
                                  as String?)
                              ?.isNotEmpty ==
                          true ||
                      (form.control(HostPlayerFormControl.profileId).value
                                  as String?)
                              ?.isNotEmpty ==
                          true;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hasLinked && name?.isNotEmpty == true
                          ? name!
                          : l10n.hostAddPlayerSelectExisting,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasLinked
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ReactiveTextField<String>(
              key: ValueKey('host-player-name-$index'),
              formControlName: HostPlayerFormControl.name,
              focusNode: nameFocusNode,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                label: AppRequiredLabel(l10n.hostAddPlayerName),
              ),
              validationMessages: {
                ValidationMessage.required: (_) =>
                    l10n.hostAddPlayerNameRequired,
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            ReactiveTextField<String>(
              formControlName: HostPlayerFormControl.phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.authSignUpPhone),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ReactiveDropdownField<Gender>(
                    formControlName: HostPlayerFormControl.gender,
                    decoration: InputDecoration(
                      labelText: l10n.hostAddPlayerGender,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: Gender.male,
                        child: Text(
                          l10n.genderMale,
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: Gender.female,
                        child: Text(
                          l10n.genderFemale,
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ReactiveDropdownField<int>(
                    formControlName: HostPlayerFormControl.level,
                    decoration: InputDecoration(
                      labelText: l10n.registrationLevel,
                    ),
                    validationMessages: {
                      ValidationMessage.required: (_) =>
                          l10n.hostAddPlayerLevelRequired,
                    },
                    items: [
                      for (final level in levels)
                        DropdownMenuItem(
                          value: level,
                          child: Text(
                            l10n.levelName(level),
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ReactiveTextField<String>(
              formControlName: HostPlayerFormControl.levelDescription,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.hostAddPlayerLevelDescription,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            HostPlayerClubFeeSection(state: state),
            ReactiveValueListenableBuilder<String>(
              formControlName: HostPlayerFormControl.profileId,
              builder: (context, profileIdControl, _) {
                return ReactiveValueListenableBuilder<String>(
                  formControlName: HostPlayerFormControl.userId,
                  builder: (context, userIdControl, _) {
                    final isManualGuest =
                        (profileIdControl.value == null ||
                            profileIdControl.value!.isEmpty) &&
                        (userIdControl.value == null ||
                            userIdControl.value!.isEmpty);
                    if (!isManualGuest && !showSaveToRosterWhenLinked) {
                      return const SizedBox.shrink();
                    }
                    final checkbox = ReactiveCheckboxListTile(
                      key: const Key('host-player-save-to-roster'),
                      formControlName: HostPlayerFormControl.saveToRoster,
                      title: Text(
                        l10n.rosterSaveToRosterCheckbox,
                        style: theme.textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: canSaveToRoster
                          ? checkbox
                          : IgnorePointer(
                              child: Opacity(opacity: 0.6, child: checkbox),
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HostPlayerClubFeeSection extends StatelessWidget {
  const HostPlayerClubFeeSection({required this.state, super.key});

  final HostAddPlayersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = ReactiveForm.of(context)! as FormGroup;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.attach_money, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.hostAddPlayerClubFee,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: ReactiveSwitch(
                    formControlName: HostPlayerFormControl.clubFeeEnabled,
                    onChanged: (control) {
                      if (control.value != true) {
                        form.control(HostPlayerFormControl.clubId).value = null;
                      }
                      form.updateValueAndValidity();
                    },
                  ),
                ),
              ],
            ),
          ),
          ReactiveValueListenableBuilder<bool>(
            formControlName: HostPlayerFormControl.clubFeeEnabled,
            builder: (context, enabled, _) {
              if (enabled.value != true) return const SizedBox.shrink();
              if (state.loadingClubData) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: LinearProgressIndicator(),
                );
              }
              if (state.clubs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Text(l10n.hostAddPlayerNoClubFee),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReactiveFormConsumer(
                      builder: (context, _, _) => ReactiveDropdownField<String>(
                        formControlName: HostPlayerFormControl.clubId,
                        decoration: InputDecoration(
                          labelText: l10n.hostAddPlayerClub,
                          errorText:
                              form.touched && form.hasError('clubRequired')
                              ? l10n.hostAddPlayerClubRequired
                              : null,
                        ),
                        items: [
                          for (final club in state.clubs)
                            DropdownMenuItem(
                              value: club.id,
                              child: Text(club.name),
                            ),
                        ],
                      ),
                    ),
                    ReactiveFormConsumer(
                      builder: (context, form, _) {
                        final clubId =
                            form.control(HostPlayerFormControl.clubId).value
                                as String?;
                        final gender =
                            form.control(HostPlayerFormControl.gender).value
                                as Gender?;
                        final fee = clubId == null
                            ? null
                            : state.feesByClubId[clubId]?.feeForGender(
                                gender == Gender.female ? 'FEMALE' : 'MALE',
                              );
                        if (fee == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            l10n.hostAddPlayerClubFeeAmount(
                              Money.vndPlain(
                                fee,
                                locale: Localizations.localeOf(
                                  context,
                                ).languageCode,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.hostAddPlayerClubFeeHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
