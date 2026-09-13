import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_team_roster.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Adds roster players to a team being edited, or creates one on the spot.
class TournamentTeamRosterPicker extends StatefulWidget {
  const TournamentTeamRosterPicker({
    required this.roster,
    required this.registrations,
    required this.editingRegistrationId,
    required this.memberIds,
    required this.isFull,
    required this.busy,
    required this.onAdd,
    required this.onCreate,
    super.key,
  });

  final List<TournamentPlayer> roster;
  final List<TournamentRegistration> registrations;
  final String editingRegistrationId;
  final List<String> memberIds;
  final bool isFull;
  final bool busy;
  final ValueChanged<String> onAdd;
  final Future<void> Function(String name) onCreate;

  @override
  State<TournamentTeamRosterPicker> createState() =>
      _TournamentTeamRosterPickerState();
}

class _TournamentTeamRosterPickerState
    extends State<TournamentTeamRosterPicker> {
  final _newName = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final candidates = [
      for (final player in widget.roster)
        if (!widget.memberIds.contains(player.id) &&
            (query.isEmpty || player.name.toLowerCase().contains(query)))
          player,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tournamentTeamsPanelAddMembersLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (widget.isFull)
          Text(
            l10n.tournamentTeamsPanelRosterFullHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          decoration: InputDecoration(
            hintText: l10n.tournamentTeamsPanelSearchPlayer,
            prefixIcon: const Icon(AppIcons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        if (candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.tournamentTeamsPanelNoRosterCandidates),
          ),
        for (final player in candidates.take(30)) _candidate(l10n, player),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.tournamentTeamsPanelQuickCreatePlayer,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _newName,
          decoration: InputDecoration(
            labelText: l10n.tournamentTeamsPanelNewPlayerNameLabel,
            hintText: l10n.tournamentTeamsPanelNewPlayerNamePlaceholder,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed:
              widget.isFull || widget.busy || _newName.text.trim().isEmpty
              ? null
              : () async {
                  await widget.onCreate(_newName.text.trim());
                  if (mounted) setState(_newName.clear);
                },
          child: Text(l10n.tournamentTeamsPanelCreateAndAdd),
        ),
      ],
    );
  }

  Widget _candidate(AppLocalizations l10n, TournamentPlayer player) {
    final otherTeams = otherTeamAssignments(
      widget.registrations,
      player.id,
      exceptRegistrationId: widget.editingRegistrationId,
      unknownName: l10n.tournamentTeamsUnknown,
    );
    final blocked = otherTeams.isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(player.name),
      subtitle: blocked
          ? Text(l10n.tournamentTeamsPanelAssignedToTeam(otherTeams.join(', ')))
          : null,
      trailing: IconButton(
        tooltip: l10n.tournamentTeamsPanelAddToTeam,
        icon: const Icon(AppIcons.addCircle),
        onPressed: blocked || widget.isFull
            ? null
            : () => widget.onAdd(player.id),
      ),
    );
  }
}
