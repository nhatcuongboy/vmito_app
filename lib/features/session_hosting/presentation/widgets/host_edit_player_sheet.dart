import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_add_players_controller.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_player_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
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
                HostPlayerForm(
                  index: 0,
                  number: widget.player.playerNumber ?? 0,
                  levels: _levels,
                  state: addState,
                  canRemove: false,
                  onRemove: () {},
                  onPickPlayer: null,
                  canPickExistingPlayer: false,
                  canSaveToRoster: false,
                  showSaveToRosterWhenLinked: true,
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
