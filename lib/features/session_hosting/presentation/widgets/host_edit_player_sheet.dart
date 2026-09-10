import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_add_players_controller.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_domain/vmito_domain.dart';

Future<bool?> showHostEditPlayerSheet(
  BuildContext context, {
  required Session session,
  required SessionPlayer player,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: .92,
    child: _HostEditPlayerSheet(session: session, player: player),
  ),
);

class _HostEditPlayerSheet extends ConsumerStatefulWidget {
  const _HostEditPlayerSheet({required this.session, required this.player});
  final Session session;
  final SessionPlayer player;

  @override
  ConsumerState<_HostEditPlayerSheet> createState() =>
      _HostEditPlayerSheetState();
}

class _HostEditPlayerSheetState extends ConsumerState<_HostEditPlayerSheet> {
  late final FormGroup _form;
  bool _submitting = false;

  List<int> get _levels =>
      (widget.session.requiredLevels.isEmpty
            ? validLevels
            : widget.session.requiredLevels.toSet().toList())
        ..sort();

  @override
  void initState() {
    super.initState();
    _form = hostPlayerEditForm(widget.player);
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(hostAddPlayersControllerProvider(widget.session.id).notifier)
            .initialize(widget.session),
      ),
    );
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
    if (_submitting || _form.invalid || _form.pending) return;
    final draft = HostPlayerEditDraft.fromForm(_form);
    final changedPaymentInputs =
        draft.gender != (widget.player.gender ?? Gender.male) ||
        draft.clubId != widget.player.clubId ||
        draft.clubFeeEnabled != (widget.player.clubId?.isNotEmpty ?? false);
    setState(() => _submitting = true);
    final succeeded = await ref
        .read(
          hostSessionManagementControllerProvider(widget.session.id).notifier,
        )
        .updatePlayer(
          widget.player.id,
          draft.toJson(),
          shouldRecalculatePayments: changedPaymentInputs,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    final l10n = AppLocalizations.of(context);
    if (succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.hostPlayerEditSuccess)),
      );
      Navigator.pop(context, true);
      return;
    }
    final error = ref
        .read(
          hostSessionManagementControllerProvider(widget.session.id),
        )
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
    final addState = ref.watch(
      hostAddPlayersControllerProvider(widget.session.id),
    );
    return AppReactiveForm<void>(
      formGroup: _form,
      child: Column(
        children: [
          AppSheetHeader(
            title: l10n.hostPlayerEditTitle(widget.player.playerNumber ?? 0),
            closeButtonEnabled: !_submitting,
            onClose: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ReactiveTextField<String>(
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
                          for (final level in _levels)
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
                const SizedBox(height: AppSpacing.md),
                _ClubFeeEditor(state: addState),
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
                        : () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('host-edit-player-submit'),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.hostPlayerEditSave),
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

class _ClubFeeEditor extends StatelessWidget {
  const _ClubFeeEditor({required this.state});
  final HostAddPlayersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = ReactiveForm.of(context)! as FormGroup;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: ReactiveValueListenableBuilder<bool>(
          formControlName: HostPlayerFormControl.clubFeeEnabled,
          builder: (context, control, _) {
            final enabled = control.value ?? false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.hostAddPlayerClubFee),
                  value: enabled,
                  onChanged: (value) {
                    control.value = value;
                    if (!value) {
                      form.control(HostPlayerFormControl.clubId).value = null;
                    }
                  },
                ),
                if (enabled) ...[
                  if (state.loadingClubData) const LinearProgressIndicator(),
                  ReactiveDropdownField<String>(
                    formControlName: HostPlayerFormControl.clubId,
                    decoration: InputDecoration(
                      label: AppRequiredLabel(l10n.hostAddPlayerClub),
                    ),
                    validationMessages: {
                      'clubRequired': (_) => l10n.hostAddPlayerClubRequired,
                    },
                    items: [
                      for (final club in state.clubs)
                        DropdownMenuItem(
                          value: club.id,
                          child: Text(
                            club.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
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
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
