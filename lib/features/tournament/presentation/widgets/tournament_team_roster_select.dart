import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_team_roster.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Checkbox list of roster players not yet registered in the category.
class TournamentTeamRosterSelect extends ConsumerStatefulWidget {
  const TournamentTeamRosterSelect({
    required this.tournamentId,
    required this.registrations,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String tournamentId;
  final List<TournamentRegistration> registrations;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  ConsumerState<TournamentTeamRosterSelect> createState() =>
      _TournamentTeamRosterSelectState();
}

class _TournamentTeamRosterSelectState
    extends ConsumerState<TournamentTeamRosterSelect> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roster = ref.watch(tournamentPlayersProvider(widget.tournamentId));
    final registered = registeredPlayerIds(widget.registrations);
    final available = [
      for (final player in roster.items)
        if (!registered.contains(player.id)) player,
    ];
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final player in available)
        if (query.isEmpty || player.name.toLowerCase().contains(query)) player,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: l10n.tournamentTeamsPanelSearchPlayer,
            prefixIcon: const Icon(AppIcons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.tournamentTeamsPanelSelectedCount(widget.selected.length)),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.4,
          child: roster.loading && !roster.loaded
              ? const Center(child: CircularProgressIndicator())
              : available.isEmpty
              ? Center(child: Text(l10n.tournamentTeamsPanelNoAvailablePlayers))
              : visible.isEmpty
              ? Center(child: Text(l10n.tournamentTeamsPanelNoRosterCandidates))
              : ListView(
                  children: [
                    for (final player in visible)
                      CheckboxListTile(
                        value: widget.selected.contains(player.id),
                        title: Text(player.name),
                        subtitle: player.code == null
                            ? null
                            : Text(player.code!),
                        onChanged: (checked) => widget.onChanged(
                          checked == true
                              ? {...widget.selected, player.id}
                              : ({...widget.selected}..remove(player.id)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
