import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/tournament/application/tournament_registrations_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_team_roster.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_team_roster_picker.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

/// Individual categories: rename the player. Team categories: name plus
/// members, capped at the category's team size.
class TournamentTeamEditor extends ConsumerStatefulWidget {
  const TournamentTeamEditor({
    required this.tournament,
    required this.category,
    required this.registration,
    super.key,
  });

  final TournamentDetail tournament;
  final TournamentCategory category;
  final TournamentRegistration registration;

  @override
  ConsumerState<TournamentTeamEditor> createState() =>
      _TournamentTeamEditorState();
}

class _TournamentTeamEditorState extends ConsumerState<TournamentTeamEditor> {
  late final _form = FormGroup({
    'name': FormControl<String>(
      value: widget.registration.displayName,
      validators: [Validators.required],
    ),
  });
  late final List<String> _memberIds = [...widget.registration.memberIds];
  bool _creating = false;

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
    final roster = ref.watch(tournamentPlayersProvider(widget.tournament.id));
    final teamSize = widget.category.teamSize;
    final conflicts = {
      for (final id in _memberIds)
        id: otherTeamAssignments(
          state.items,
          id,
          exceptRegistrationId: widget.registration.id,
          unknownName: l10n.tournamentTeamsUnknown,
        ),
    }..removeWhere((_, teams) => teams.isEmpty);
    return TournamentEditorFrame(
      title: _isTeam
          ? l10n.tournamentTeamsPanelTeamEditTitle
          : l10n.tournamentTeamsPanelPlayerEditTitle,
      form: _form,
      busy: state.busy || _creating,
      error: state.error,
      canSave: !_isTeam || (conflicts.isEmpty && _memberIds.length <= teamSize),
      onSave: _submit,
      children: [
        ReactiveTextField<String>(
          formControlName: 'name',
          decoration: InputDecoration(
            label: AppRequiredLabel(
              _isTeam
                  ? l10n.tournamentTeamsPanelTeamNameLabel
                  : l10n.tournamentTeamsPanelPlayerNamePlaceholder,
            ),
          ),
        ),
        if (_isTeam) ...[
          Text(
            '${l10n.tournamentTeamsPanelSelectedMembers} · '
            '${l10n.tournamentTeamsPanelMemberCount(_memberIds.length, teamSize)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_memberIds.isEmpty)
            Text(l10n.tournamentTeamsPanelNoSelectedMembers),
          for (final id in _memberIds)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                roster.items.where((p) => p.id == id).firstOrNull?.name ??
                    l10n.tournamentTeamsPanelUnknownPlayer,
              ),
              subtitle: conflicts[id] == null
                  ? null
                  : Text(
                      l10n.tournamentTeamsPanelMemberConflict(
                        conflicts[id]!.join(', '),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
              trailing: IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: const Icon(AppIcons.removeCircle),
                onPressed: () => setState(() => _memberIds.remove(id)),
              ),
            ),
          if (conflicts.isNotEmpty)
            Text(
              l10n.tournamentTeamsPanelRosterConflictHelp,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_memberIds.length < teamSize)
            Text(
              l10n.tournamentTeamsPanelDraftTeamWarning,
              style: const TextStyle(color: AppColors.warning),
            ),
          TournamentTeamRosterPicker(
            roster: roster.items,
            registrations: state.items,
            editingRegistrationId: widget.registration.id,
            memberIds: _memberIds,
            isFull: _memberIds.length >= teamSize,
            busy: state.busy || _creating || roster.busy,
            onAdd: (id) => setState(() => _memberIds.add(id)),
            onCreate: _createMember,
          ),
        ],
      ],
    );
  }

  Future<void> _createMember(String name) async {
    setState(() => _creating = true);
    final players = ref.read(
      tournamentPlayersProvider(widget.tournament.id).notifier,
    );
    final created = await players.save(PlayerDraft(name: name));
    if (!mounted) return;
    final roster = ref.read(tournamentPlayersProvider(widget.tournament.id));
    setState(() {
      _creating = false;
      // `save` appends the server's player to the end of the roster.
      if (created && roster.items.isNotEmpty) {
        _memberIds.add(roster.items.last.id);
      }
    });
    if (!created) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).tournamentTeamsPanelMemberCreateFailed,
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    final name = (_form.control('name').value as String).trim();
    final controller = ref.read(tournamentRegistrationsProvider(_key).notifier);
    final playerId = widget.registration.singlePlayerId;
    final saved = _isTeam
        ? await controller.saveTeam(
            widget.category,
            widget.registration,
            name: name,
            memberIds: _memberIds,
          )
        : playerId == null || await controller.renamePlayer(playerId, name);
    if (saved && mounted) Navigator.pop(context);
  }
}
