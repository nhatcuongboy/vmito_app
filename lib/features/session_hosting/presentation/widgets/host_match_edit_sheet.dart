import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/form/match_edit_form.dart';
import 'package:vmito_app/features/session/domain/match_result_summary.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_match_actions_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

Future<bool?> showHostMatchEditSheet(
  BuildContext context, {
  required Session session,
  required Match match,
  required CourtDirection direction,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: .92,
    child: _HostMatchEditSheet(
      session: session,
      match: match,
      direction: direction,
    ),
  ),
);

class _HostMatchEditSheet extends ConsumerStatefulWidget {
  const _HostMatchEditSheet({
    required this.session,
    required this.match,
    required this.direction,
  });

  final Session session;
  final Match match;
  final CourtDirection direction;

  @override
  ConsumerState<_HostMatchEditSheet> createState() =>
      _HostMatchEditSheetState();
}

class _HostMatchEditSheetState extends ConsumerState<_HostMatchEditSheet> {
  late final FormGroup _form;
  late final StreamSubscription<bool?> _noResultSubscription;

  int get _playerCount => widget.match.orderedPlayerIds.length;

  @override
  void initState() {
    super.initState();
    final result = matchResult(widget.match, direction: widget.direction);
    _form = matchEditForm(
      match: widget.match,
      pair1Score: result.first,
      pair2Score: result.second,
    );
    final noResult = _form.control(MatchEditFormControl.noResult);
    _syncScoreControls(noResult.value as bool? ?? false);
    _noResultSubscription = noResult.valueChanges.cast<bool?>().listen(
      (value) => _syncScoreControls(value ?? false),
    );
  }

  @override
  void dispose() {
    unawaited(_noResultSubscription.cancel());
    _form.dispose();
    super.dispose();
  }

  void _syncScoreControls(bool noResult) {
    for (final name in const [
      MatchEditFormControl.pair1Score,
      MatchEditFormControl.pair2Score,
    ]) {
      final control = _form.control(name);
      if (noResult) {
        control.markAsDisabled(updateParent: false);
      } else {
        control.markAsEnabled(updateParent: false);
      }
    }
    _form.updateValueAndValidity();
  }

  Future<void> _submit() async {
    _form
      ..markAllAsTouched()
      ..updateValueAndValidity();
    final actions = ref.read(
      hostMatchActionsControllerProvider(widget.session.id),
    );
    if (actions.isBusy(widget.match.id) || _form.invalid || _form.pending) {
      setState(() {});
      return;
    }
    final draft = matchUpdateDraftFromForm(
      _form,
      playerCount: _playerCount,
      direction: widget.direction,
    );
    final succeeded = await ref
        .read(hostMatchActionsControllerProvider(widget.session.id).notifier)
        .update(widget.match.id, draft);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.hostResultsUpdateSuccess)),
      );
      Navigator.pop(context, true);
      return;
    }
    final error = ref
        .read(hostMatchActionsControllerProvider(widget.session.id))
        .error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is ApiException
              ? l10n.apiError(error)
              : l10n.hostResultsUpdateError,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref
        .watch(hostMatchActionsControllerProvider(widget.session.id))
        .isBusy(widget.match.id);
    final isSingles = _playerCount <= 2;
    final firstIndexes = isSingles
        ? const [0]
        : widget.direction == CourtDirection.vertical
        ? const [0, 2]
        : const [0, 1];
    final secondIndexes = isSingles
        ? const [1]
        : widget.direction == CourtDirection.vertical
        ? const [1, 3]
        : const [2, 3];
    return AppReactiveForm<void>(
      formGroup: _form,
      child: Column(
        children: [
          AppSheetHeader(
            title: l10n.hostResultsEditMatch,
            closeButtonEnabled: !busy,
            onClose: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ReactiveSwitchListTile(
                  key: const Key('host-match-edit-no-result'),
                  formControlName: MatchEditFormControl.noResult,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.hostResultsNoResult),
                ),
                ReactiveValueListenableBuilder<bool>(
                  formControlName: MatchEditFormControl.noResult,
                  builder: (context, control, _) => Opacity(
                    opacity: control.value == true ? .5 : 1,
                    child: IgnorePointer(
                      ignoring: control.value == true,
                      child: Row(
                        children: [
                          Expanded(
                            child: ReactiveTextField<String>(
                              key: const Key('host-match-edit-score-1'),
                              formControlName: MatchEditFormControl.pair1Score,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                label: AppOptionalLabel(
                                  isSingles
                                      ? l10n.hostResultsPlayer1
                                      : l10n.hostResultsPair1,
                                  optionalText: l10n.formOptional,
                                ),
                              ),
                              validationMessages: {
                                'nonNegativeNumber': (_) =>
                                    l10n.hostResultsInvalidNumber,
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ReactiveTextField<String>(
                              key: const Key('host-match-edit-score-2'),
                              formControlName: MatchEditFormControl.pair2Score,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                label: AppOptionalLabel(
                                  isSingles
                                      ? l10n.hostResultsPlayer2
                                      : l10n.hostResultsPair2,
                                  optionalText: l10n.formOptional,
                                ),
                              ),
                              validationMessages: {
                                'nonNegativeNumber': (_) =>
                                    l10n.hostResultsInvalidNumber,
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.hostResultsPlayers,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TeamPlayersEditor(
                        title: isSingles
                            ? l10n.hostResultsPlayer1
                            : l10n.hostResultsPair1,
                        indexes: firstIndexes,
                        session: widget.session,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _TeamPlayersEditor(
                        title: isSingles
                            ? l10n.hostResultsPlayer2
                            : l10n.hostResultsPair2,
                        indexes: secondIndexes,
                        session: widget.session,
                      ),
                    ),
                  ],
                ),
                ReactiveFormConsumer(
                  builder: (context, form, _) =>
                      form.hasError(
                        'duplicatePlayers',
                      )
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            l10n.hostResultsDuplicatePlayers,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.md),
                ReactiveSwitchListTile(
                  key: const Key('host-match-edit-extra'),
                  formControlName: MatchEditFormControl.isExtra,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.hostResultsExtraMatch),
                ),
                ReactiveTextField<String>(
                  key: const Key('host-match-edit-shuttlecocks'),
                  formControlName: MatchEditFormControl.shuttlecockCount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    label: AppOptionalLabel(
                      l10n.hostResultsShuttlecockCount,
                      optionalText: l10n.formOptional,
                    ),
                    hintText: l10n.hostResultsShuttlecockHint,
                  ),
                  validationMessages: {
                    'nonNegativeNumber': (_) => l10n.hostResultsInvalidNumber,
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveTextField<String>(
                  key: const Key('host-match-edit-notes'),
                  formControlName: MatchEditFormControl.notes,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    label: AppOptionalLabel(
                      l10n.hostResultsNotes,
                      optionalText: l10n.formOptional,
                    ),
                    hintText: l10n.hostResultsNotesHint,
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
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('host-match-edit-submit'),
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.hostResultsSaveChanges),
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

class _TeamPlayersEditor extends StatelessWidget {
  const _TeamPlayersEditor({
    required this.title,
    required this.indexes,
    required this.session,
  });

  final String title;
  final List<int> indexes;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final index in indexes) ...[
              ReactiveDropdownField<String>(
                key: Key('host-match-edit-player-$index'),
                formControlName: MatchEditFormControl.player(index),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.hostResultsPlayerPosition(index + 1),
                ),
                items: [
                  for (final player in session.players)
                    DropdownMenuItem(
                      value: player.id,
                      child: Text(
                        player.playerNumber == null
                            ? (player.displayName ??
                                  l10n.hostResultsSelectPlayer)
                            : '#${player.playerNumber} ${player.displayName ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                ],
              ),
              if (index != indexes.last) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
