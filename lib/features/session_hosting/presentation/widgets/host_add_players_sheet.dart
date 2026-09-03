import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_add_players_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
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
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: .96,
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
        type: AppConfirmDialogType.submit,
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
    setState(
      () => _players.add(hostPlayerRowForm(defaultLevel: _defaultLevel)),
    );
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
    return AppReactiveForm(
      formGroup: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(AppIcons.userPlus, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ReactiveFormConsumer(
                    builder: (context, _, _) => Text(
                      l10n.hostAddPlayerTitle(_players.controls.length),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonCancel,
                  onPressed: state.submitting
                      ? null
                      : () => Navigator.pop(context, false),
                  icon: const Icon(AppIcons.close, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReactiveFormArray<Map<String, Object?>>(
              formArrayName: HostPlayerFormControl.players,
              builder: (context, array, _) => ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: array.controls.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  if (index == array.controls.length) {
                    return OutlinedButton.icon(
                      key: const Key('host-add-player-row'),
                      onPressed: state.submitting ? null : _addRow,
                      icon: const Icon(AppIcons.add),
                      label: Text(l10n.hostAddPlayerAddAnother),
                    );
                  }
                  return AppReactiveForm(
                    formGroup: array.controls[index] as FormGroup,
                    child: _PlayerFormCard(
                      key: ValueKey(array.controls[index]),
                      index: index,
                      number: _firstPlayerNumber + index,
                      session: widget.session,
                      levels: _levels,
                      state: state,
                      canRemove: array.controls.length > 1,
                      onRemove: () => setState(() => array.removeAt(index)),
                      rows: array.controls.cast<FormGroup>(),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.hostAddPlayerSaveAll(_players.controls.length),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerFormCard extends ConsumerWidget {
  const _PlayerFormCard({
    required this.index,
    required this.number,
    required this.session,
    required this.levels,
    required this.state,
    required this.canRemove,
    required this.onRemove,
    required this.rows,
    super.key,
  });

  final int index;
  final int number;
  final Session session;
  final List<int> levels;
  final HostAddPlayersState state;
  final bool canRemove;
  final VoidCallback onRemove;
  final List<FormGroup> rows;

  FormGroup _form(BuildContext context) =>
      ReactiveForm.of(context)! as FormGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                Expanded(child: Text(l10n.hostAddPlayerNewPlayer)),
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
              onPressed: () => _pickUser(context, ref),
              icon: const Icon(AppIcons.search),
              label: ReactiveValueListenableBuilder<String>(
                formControlName: HostPlayerFormControl.userId,
                builder: (context, control, _) {
                  final selectedName = control.value == null
                      ? null
                      : _form(context).control(HostPlayerFormControl.name).value
                            as String?;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      selectedName?.isNotEmpty == true
                          ? selectedName!
                          : l10n.hostAddPlayerSelectExisting,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ReactiveTextField<String>(
              key: ValueKey('host-player-name-$index'),
              formControlName: HostPlayerFormControl.name,
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
                      label: AppRequiredLabel(l10n.hostAddPlayerGender),
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
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ReactiveDropdownField<int>(
                    formControlName: HostPlayerFormControl.level,
                    decoration: InputDecoration(
                      label: AppRequiredLabel(l10n.registrationLevel),
                    ),
                    validationMessages: {
                      ValidationMessage.required: (_) =>
                          l10n.hostAddPlayerLevelRequired,
                    },
                    items: [
                      for (final level in levels)
                        DropdownMenuItem(
                          value: level,
                          child: Text(l10n.levelName(level)),
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
          ],
        ),
      ),
    );
  }

  Future<void> _pickUser(BuildContext context, WidgetRef ref) async {
    final form = _form(context);
    final choice = await showModalBottomSheet<_UserChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _UserPicker(
        sessionId: session.id,
        existingUserIds: session.players
            .map((player) => player.userId)
            .whereType<String>()
            .toSet(),
        selectedUserIds: rows
            .where((row) => !identical(row, form))
            .map(
              (row) =>
                  row.control(HostPlayerFormControl.userId).value as String?,
            )
            .whereType<String>()
            .toSet(),
      ),
    );
    if (!context.mounted || choice == null) return;
    final user = choice.user;
    if (choice.clear) {
      form.patchValue({
        HostPlayerFormControl.userId: null,
        HostPlayerFormControl.name: '',
        HostPlayerFormControl.gender: Gender.male,
        HostPlayerFormControl.level: session.requiredLevels.isEmpty
            ? validLevels.first
            : levels.first,
        HostPlayerFormControl.levelDescription: '',
        HostPlayerFormControl.clubFeeEnabled: false,
        HostPlayerFormControl.clubId: null,
      });
      return;
    }
    if (user == null) return;
    form.patchValue({
      HostPlayerFormControl.userId: user.id,
      HostPlayerFormControl.name: user.name,
      HostPlayerFormControl.gender: user.gender == Gender.female
          ? Gender.female
          : Gender.male,
      if (user.level != null) HostPlayerFormControl.level: user.level,
      HostPlayerFormControl.levelDescription: user.levelDescription ?? '',
    });
    final sessionClubId = session.clubId;
    if (sessionClubId != null &&
        state.monthlyMemberUserIds.contains(user.id) &&
        state.feesByClubId.containsKey(sessionClubId)) {
      form.patchValue({
        HostPlayerFormControl.clubFeeEnabled: true,
        HostPlayerFormControl.clubId: sessionClubId,
      });
    }
  }
}

class _UserPicker extends ConsumerStatefulWidget {
  const _UserPicker({
    required this.sessionId,
    required this.existingUserIds,
    required this.selectedUserIds,
  });

  final String sessionId;
  final Set<String> existingUserIds;
  final Set<String> selectedUserIds;

  @override
  ConsumerState<_UserPicker> createState() => _UserPickerState();
}

class _UserChoice {
  const _UserChoice.user(this.user) : clear = false;
  const _UserChoice.clear() : user = null, clear = true;

  final HostPlayerUserOption? user;
  final bool clear;
}

class _UserPickerState extends ConsumerState<_UserPicker> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      hostAddPlayersControllerProvider(widget.sessionId),
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.search),
                hintText: l10n.commonSearch,
              ),
              onChanged: (query) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 400),
                  () => ref
                      .read(
                        hostAddPlayersControllerProvider(
                          widget.sessionId,
                        ).notifier,
                      )
                      .searchUsers(query),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(AppIcons.add),
            title: Text(l10n.hostAddPlayerCreateNew),
            onTap: () => Navigator.pop(context, const _UserChoice.clear()),
          ),
          if (state.loadingUsers) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: state.users.length,
              itemBuilder: (context, index) {
                final user = state.users[index];
                final disabled =
                    widget.existingUserIds.contains(user.id) ||
                    widget.selectedUserIds.contains(user.id);
                return ListTile(
                  enabled: !disabled,
                  leading: const CircleAvatar(child: Icon(AppIcons.user)),
                  title: Text(user.name),
                  subtitle: Text(
                    disabled ? l10n.hostAddPlayerAlreadySelected : user.email,
                  ),
                  onTap: disabled
                      ? null
                      : () => Navigator.pop(context, _UserChoice.user(user)),
                );
              },
            ),
          ),
        ],
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
          ReactiveSwitchListTile(
            formControlName: HostPlayerFormControl.clubFeeEnabled,
            title: Text(l10n.hostAddPlayerClubFee),
            secondary: const Icon(Icons.attach_money),
            onChanged: (control) {
              if (control.value != true) {
                form.control(HostPlayerFormControl.clubId).value = null;
              }
              form.updateValueAndValidity();
            },
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
