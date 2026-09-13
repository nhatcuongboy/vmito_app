import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_registrations_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_team_roster_select.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

enum _AddMode { single, select, multiple }

/// Resolves to true when at least one registration was added.
Future<bool> showTournamentTeamAddSheet(
  BuildContext context, {
  required TournamentDetail tournament,
  required TournamentCategory category,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AddSheet(tournament: tournament, category: category),
    ) ??
    false;

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet({required this.tournament, required this.category});

  final TournamentDetail tournament;
  final TournamentCategory category;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  final _form = FormGroup({
    'name': FormControl<String>(),
    'names': FormControl<String>(),
  });
  _AddMode _mode = _AddMode.single;
  Set<String> _selected = {};

  bool get _isTeam =>
      widget.category.registrationMode == TournamentRegistrationMode.team;

  CategoryRegistrationsKey get _key =>
      (tournamentId: widget.tournament.id, categoryId: widget.category.id);

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(tournamentRegistrationsProvider(_key));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: AppReactiveForm<void>(
        formGroup: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isTeam
                  ? l10n.tournamentTeamsPanelTeamAddTitle
                  : l10n.tournamentTeamsPanelPlayerAddTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<_AddMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _AddMode.single,
                  label: Text(l10n.tournamentTeamsPanelSingle),
                ),
                // Picking existing roster players only exists for individual
                // categories; team entries are built in the team editor.
                if (!_isTeam)
                  ButtonSegment(
                    value: _AddMode.select,
                    label: Text(l10n.tournamentTeamsPanelSelectFromList),
                  ),
                ButtonSegment(
                  value: _AddMode.multiple,
                  label: Text(l10n.tournamentTeamsPanelMultiple),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
            const SizedBox(height: AppSpacing.md),
            switch (_mode) {
              // Distinct keys: both fields share a slot, and a reused field
              // element would stay bound to the other mode's control.
              _AddMode.single => ReactiveTextField<String>(
                key: const ValueKey('single-name'),
                formControlName: 'name',
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _isTeam
                      ? l10n.tournamentTeamsPanelTeamNamePlaceholder
                      : l10n.tournamentTeamsPanelPlayerNamePlaceholder,
                ),
                onChanged: (_) => setState(() {}),
              ),
              _AddMode.select => TournamentTeamRosterSelect(
                tournamentId: widget.tournament.id,
                registrations: state.items,
                selected: _selected,
                onChanged: (value) => setState(() => _selected = value),
              ),
              _AddMode.multiple => ReactiveTextField<String>(
                key: const ValueKey('multiple-names'),
                formControlName: 'names',
                keyboardType: TextInputType.multiline,
                minLines: 4,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: _isTeam
                      ? l10n.tournamentTeamsPanelTeamMultiPlaceholder
                      : l10n.tournamentTeamsPanelPlayerMultiPlaceholder,
                ),
                onChanged: (_) => setState(() {}),
              ),
            },
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                resourceErrorMessage(context, state.error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: state.busy || !_hasInput ? null : _submit,
              child: Text(
                state.busy ? l10n.commonLoading : l10n.tournamentResourceAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _name => (_form.control('name').value as String?)?.trim() ?? '';

  List<String> get _names => [
    for (final line in ((_form.control('names').value as String?) ?? '').split(
      '\n',
    ))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  bool get _hasInput => switch (_mode) {
    _AddMode.single => _name.isNotEmpty,
    _AddMode.select => _selected.isNotEmpty,
    _AddMode.multiple => _names.isNotEmpty,
  };

  Future<void> _submit() async {
    final controller = ref.read(tournamentRegistrationsProvider(_key).notifier);
    final added = await switch (_mode) {
      _AddMode.single => controller.addOne(widget.category, _name),
      _AddMode.select => controller.addFromRoster(_selected.toList()),
      _AddMode.multiple => controller.addMany(_names),
    };
    if (added && mounted) Navigator.pop(context, true);
  }
}
