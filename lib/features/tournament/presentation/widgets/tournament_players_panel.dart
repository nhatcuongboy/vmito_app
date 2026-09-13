import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_player_details.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_player_editor.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_player_import_editor.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// Filters and forms are local; resource mutations go through Riverpod.
class TournamentPlayersPanel extends ConsumerStatefulWidget {
  const TournamentPlayersPanel({required this.tournamentId, super.key});
  final String tournamentId;
  @override
  ConsumerState<TournamentPlayersPanel> createState() => _PlayersState();
}

class _PlayersState extends ConsumerState<TournamentPlayersPanel> {
  final search = FormGroup({
    ResourceControl.query: FormControl<String>(value: ''),
  });
  int linkedFilter = 0;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(tournamentPlayersProvider(widget.tournamentId));
    final controller = ref.read(
      tournamentPlayersProvider(widget.tournamentId).notifier,
    );
    final query = resourceText(search, ResourceControl.query) ?? '';
    final items =
        state.items
            .where(
              (p) =>
                  p.matches(query) &&
                  (linkedFilter == 0 ||
                      (linkedFilter == 1) == (p.userId?.isNotEmpty ?? false)),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return TournamentResourceFrame(
      loading: state.loading,
      error: state.error,
      onRetry: controller.reload,
      header: [
        Text(
          l.tournamentManagePlayers,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        AppReactiveForm<void>(
          formGroup: search,
          child: ReactiveTextField<String>(
            formControlName: ResourceControl.query,
            decoration: InputDecoration(
              labelText: l.commonSearch,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in [
              l.tournamentPlayerAll,
              l.tournamentPlayerLinked,
              l.tournamentPlayerUnlinked,
            ].indexed)
              ChoiceChip(
                label: Text(entry.$2),
                selected: linkedFilter == entry.$1,
                onSelected: (_) => setState(() => linkedFilter = entry.$1),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: state.busy || !state.loaded ? null : _edit,
              icon: const Icon(Icons.add),
              label: Text(l.tournamentResourceAdd),
            ),
            OutlinedButton(
              onPressed: state.busy || !state.loaded
                  ? null
                  : () => openResourceEditor(
                      context,
                      TournamentPlayerImportEditor(
                        tournamentId: widget.tournamentId,
                      ),
                    ),
              child: Text(l.tournamentPlayerImport),
            ),
          ],
        ),
      ],
      children: [
        if (items.isEmpty && !state.loading)
          ListTile(title: Text(l.tournamentResourceEmpty)),
        for (final player in items)
          Card(
            child: ListTile(
              title: Text(player.name),
              subtitle: Text(
                [
                  player.code,
                  player.email,
                  player.phone,
                  player.userName,
                ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
              ),
              onTap: () => openResourceEditor(
                context,
                TournamentPlayerDetails(player: player),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l.commonEdit,
                    icon: const Icon(Icons.edit),
                    onPressed: state.busy ? null : () => _edit(player),
                  ),
                  IconButton(
                    tooltip: l.commonDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: state.busy
                        ? null
                        : () async {
                            if (await confirmResourceDelete(
                              context,
                              player.name,
                            )) {
                              await controller.delete(player.id);
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _edit([TournamentPlayer? player]) => openResourceEditor(
    context,
    TournamentPlayerEditor(tournamentId: widget.tournamentId, player: player),
  );
}
