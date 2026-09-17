import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_add_players_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_player_picker_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_full_height_modal.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_domain/vmito_domain.dart';

Future<bool?> showHostAddPlayersSheet(
  BuildContext context, {
  required Session session,
}) async {
  final capacity = session.numberOfCourts * session.maxPlayersPerCourt;
  if (capacity > 0 && session.players.length >= capacity) {
    final proceed = await _confirmPlayerLimit(
      context,
      session: session,
      currentCount: session.players.length,
    );
    if (!proceed || !context.mounted) return false;
  }
  return showAppFullHeightModal<bool>(
    context,
    // The sheet remains draggable without a visible handle. Material reserves
    // a separate 48dp row for that handle, which makes AppSheetHeader look
    // noticeably looser than the other hosting sheets.
    builder: (context) => FractionallySizedBox(
      // `useSafeArea` already leaves room for the status bar. Filling the
      // remaining height avoids adding a second, visible gap above the sheet.
      heightFactor: 1,
      child: _HostAddPlayersSheet(session: session),
    ),
  );
}

Future<bool> _confirmPlayerLimit(
  BuildContext context, {
  required Session session,
  required int currentCount,
}) async {
  final l10n = AppLocalizations.of(context);
  return await showAppConfirmDialog(
        context,
        icon: const Icon(Icons.warning_amber_rounded),
        title: l10n.hostAddPlayerLimitTitle,
        content: l10n.hostAddPlayerLimitDescription(
          currentCount,
          session.numberOfCourts,
          session.maxPlayersPerCourt,
        ),
        confirmLabel: l10n.hostAddPlayerAddAnyway,
      ) ??
      false;
}

class _HostAddPlayersSheet extends ConsumerStatefulWidget {
  const _HostAddPlayersSheet({required this.session});

  final Session session;

  @override
  ConsumerState<_HostAddPlayersSheet> createState() =>
      _HostAddPlayersSheetState();
}

class _HostAddPlayersSheetState extends ConsumerState<_HostAddPlayersSheet> {
  late final FormGroup _form;
  final Map<FormGroup, FocusNode> _nameFocusNodes = {};

  FocusNode _nameFocusNode(FormGroup row) =>
      _nameFocusNodes.putIfAbsent(row, FocusNode.new);

  FormArray<Map<String, Object?>> get _players =>
      _form.control(HostPlayerFormControl.players)
          as FormArray<Map<String, Object?>>;

  int? get _defaultLevel => widget.session.requiredLevels.isEmpty
      ? validLevels.first
      : widget.session.requiredLevels.reduce((a, b) => a < b ? a : b);

  List<int> get _levels =>
      widget.session.requiredLevels.isEmpty
            ? validLevels
            : widget.session.requiredLevels.toSet().toList()
        ..sort();

  int get _firstPlayerNumber {
    var maximum = 0;
    for (final player in widget.session.players) {
      if ((player.playerNumber ?? 0) > maximum) maximum = player.playerNumber!;
    }
    return maximum + 1;
  }

  @override
  void initState() {
    super.initState();
    _form = FormGroup({
      HostPlayerFormControl.players: FormArray<Map<String, Object?>>([
        hostPlayerRowForm(defaultLevel: _defaultLevel),
      ]),
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final firstRow = _players.controls.first as FormGroup;
      _nameFocusNode(firstRow).requestFocus();
    });
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(
              hostAddPlayersControllerProvider(widget.session.id).notifier,
            )
            .initialize(widget.session),
      ),
    );
  }

  @override
  void dispose() {
    for (final node in _nameFocusNodes.values) {
      node.dispose();
    }
    _form.dispose();
    super.dispose();
  }

  Future<void> _addRow() async {
    final capacity =
        widget.session.numberOfCourts * widget.session.maxPlayersPerCourt;
    final currentCount =
        widget.session.players.length + _players.controls.length;
    if (capacity > 0 && currentCount >= capacity) {
      final proceed = await _confirmPlayerLimit(
        context,
        session: widget.session,
        currentCount: currentCount,
      );
      if (!proceed || !mounted) return;
    }
    final row = hostPlayerRowForm(defaultLevel: _defaultLevel);
    setState(() => _players.add(row));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode(row).requestFocus();
    });
  }

  Future<void> _pickPlayer(FormGroup row) async {
    final existingProfileIds = <String>{};
    final existingUserIds = widget.session.players
        .map((p) => p.userId)
        .whereType<String>()
        .toSet();

    for (final control in _players.controls) {
      final r = control as FormGroup;
      if (identical(r, row)) continue;
      final profileId =
          r.control(HostPlayerFormControl.profileId).value as String?;
      if (profileId != null && profileId.isNotEmpty) {
        existingProfileIds.add(profileId);
      }
      final uId = r.control(HostPlayerFormControl.userId).value as String?;
      if (uId != null && uId.isNotEmpty) {
        existingUserIds.add(uId);
      }
    }

    final selected = await showHostPlayerPickerSheet(
      context,
      sessionId: widget.session.id,
      clubId: widget.session.clubId,
      existingProfileIds: existingProfileIds,
      existingUserIds: existingUserIds,
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    final sessionClubId = widget.session.clubId;
    final state = ref.read(hostAddPlayersControllerProvider(widget.session.id));

    final first = selected.first;
    row.patchValue({
      HostPlayerFormControl.name: first.name,
      HostPlayerFormControl.gender: first.gender ?? Gender.male,
      if (first.level != null) HostPlayerFormControl.level: first.level,
      if (first.levelDescription != null)
        HostPlayerFormControl.levelDescription: first.levelDescription,
      HostPlayerFormControl.phone: first.phone ?? '',
      HostPlayerFormControl.userId: first.userId,
      HostPlayerFormControl.profileId: first.profileId,
      if (first.profileId != null) HostPlayerFormControl.saveToRoster: false,
    });

    if (sessionClubId != null &&
        first.isMonthlyMember &&
        state.feesByClubId.containsKey(sessionClubId)) {
      row.patchValue({
        HostPlayerFormControl.clubFeeEnabled: true,
        HostPlayerFormControl.clubId: sessionClubId,
      });
    }

    for (final player in selected.skip(1)) {
      final newRow = hostPlayerRowForm(
        defaultLevel: player.level ?? _defaultLevel,
        profileId: player.profileId,
        saveToRoster: player.profileId == null,
      )..patchValue({
          HostPlayerFormControl.name: player.name,
          HostPlayerFormControl.gender: player.gender ?? Gender.male,
          if (player.level != null) HostPlayerFormControl.level: player.level,
          if (player.levelDescription != null)
            HostPlayerFormControl.levelDescription: player.levelDescription,
          HostPlayerFormControl.phone: player.phone ?? '',
          HostPlayerFormControl.userId: player.userId,
          HostPlayerFormControl.profileId: player.profileId,
          if (player.profileId != null)
            HostPlayerFormControl.saveToRoster: false,
        });

      if (sessionClubId != null &&
          player.isMonthlyMember &&
          state.feesByClubId.containsKey(sessionClubId)) {
        newRow.patchValue({
          HostPlayerFormControl.clubFeeEnabled: true,
          HostPlayerFormControl.clubId: sessionClubId,
        });
      }
      _players.add(newRow);
    }
    setState(() {});
  }

  Future<void> _submit() async {
    _form
      ..markAllAsTouched()
      ..updateValueAndValidity();
    if (_form.invalid || _form.pending) return;
    final controller = ref.read(
      hostAddPlayersControllerProvider(widget.session.id).notifier,
    );
    final drafts = _players.controls
        .cast<FormGroup>()
        .map(HostPlayerDraft.fromForm)
        .toList(growable: false);
    final success = await controller.submit(drafts);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.hostAddPlayerSuccess(drafts.length))),
      );
      Navigator.pop(context, true);
      return;
    }
    final error = ref
        .read(hostAddPlayersControllerProvider(widget.session.id))
        .error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is ApiException ? l10n.apiError(error) : l10n.errorUnknown,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      hostAddPlayersControllerProvider(widget.session.id),
    );
    return PopScope(
      canPop: !state.submitting,
      child: AppReactiveForm<void>(
        formGroup: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(
              key: const Key('host-add-players-header'),
              title: l10n.hostAddPlayerAddAnother,
              closeButtonKey: const Key('host-add-players-close'),
              closeButtonEnabled: !state.submitting,
              onClose: () => Navigator.pop(context, false),
            ),
            Expanded(
              child: ReactiveFormArray<Map<String, Object?>>(
                key: const ValueKey('player-form-list'),
                formArrayName: HostPlayerFormControl.players,
                builder: (context, array, _) => ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: array.controls.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == array.controls.length) {
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('host-add-player-row'),
                          onPressed: state.submitting ? null : _addRow,
                          icon: const Icon(AppIcons.add),
                          label: Text(l10n.hostAddPlayerAddAnother),
                        ),
                      );
                    }
                    final row = array.controls[index] as FormGroup;
                    return AppReactiveForm<void>(
                      formGroup: row,
                      child: _PlayerFormCard(
                        key: ValueKey(row),
                        index: index,
                        number: _firstPlayerNumber + index,
                        levels: _levels,
                        state: state,
                        canRemove: array.controls.length > 1,
                        nameFocusNode: _nameFocusNode(row),
                        onRemove: () => setState(() {
                          array.removeAt(index);
                          _nameFocusNodes.remove(row)?.dispose();
                        }),
                        onPickPlayer: () => _pickPlayer(row),
                      ),
                    );
                  },
                ),
              ),
            ),
            AppSheetActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: state.submitting
                          ? null
                          : () => Navigator.pop(context, false),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const Key('host-add-player-submit'),
                      onPressed: state.submitting ? null : _submit,
                      child: state.submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              l10n.hostAddPlayerSaveAll(
                                _players.controls.length,
                              ),
                            ),
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

class _PlayerFormCard extends StatelessWidget {
  const _PlayerFormCard({
    required this.index,
    required this.number,
    required this.levels,
    required this.state,
    required this.canRemove,
    required this.nameFocusNode,
    required this.onRemove,
    required this.onPickPlayer,
    super.key,
  });

  final int index;
  final int number;
  final List<int> levels;
  final HostAddPlayersState state;
  final bool canRemove;
  final FocusNode nameFocusNode;
  final VoidCallback onRemove;
  final VoidCallback onPickPlayer;

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
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Row(
                    children: [
                      Text(l10n.hostAddPlayerNewPlayer),
                      ReactiveValueListenableBuilder<String>(
                        formControlName: HostPlayerFormControl.profileId,
                        builder: (context, control, _) {
                          if (control.value == null || control.value!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.rosterPlayerBadge,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
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
              onPressed: onPickPlayer,
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                side: BorderSide(color: theme.dividerColor),
              ),
              icon: Icon(
                AppIcons.search,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              label: ReactiveFormConsumer(
                builder: (context, form, _) {
                  final name =
                      form.control(HostPlayerFormControl.name).value as String?;
                  final hasLinked =
                      form.control(HostPlayerFormControl.userId).value != null ||
                      form.control(HostPlayerFormControl.profileId).value != null;
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
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ),
                      DropdownMenuItem(
                        value: Gender.female,
                        child: Text(
                          l10n.genderFemale,
                          style: const TextStyle(fontWeight: FontWeight.normal),
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
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.hostAddPlayerLevelDescription,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ClubFeeSection(state: state),
            ReactiveValueListenableBuilder<String>(
              formControlName: HostPlayerFormControl.profileId,
              builder: (context, profileIdControl, _) {
                return ReactiveValueListenableBuilder<String>(
                  formControlName: HostPlayerFormControl.userId,
                  builder: (context, userIdControl, _) {
                    final isManualGuest = (profileIdControl.value == null ||
                            profileIdControl.value!.isEmpty) &&
                        (userIdControl.value == null ||
                            userIdControl.value!.isEmpty);
                    if (!isManualGuest) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: ReactiveCheckboxListTile(
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


class _ClubFeeSection extends StatelessWidget {
  const _ClubFeeSection({required this.state});

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
