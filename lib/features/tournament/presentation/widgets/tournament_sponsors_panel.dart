import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_sponsor_editor.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentSponsorsPanel extends ConsumerWidget {
  const TournamentSponsorsPanel({required this.tournamentId, super.key});
  final String tournamentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(tournamentSponsorsProvider(tournamentId));
    final controller = ref.read(
      tournamentSponsorsProvider(tournamentId).notifier,
    );
    final items = [...state.items]
      ..sort((a, b) {
        final order = a.displayOrder.compareTo(b.displayOrder);
        return order == 0 ? a.name.compareTo(b.name) : order;
      });
    return TournamentResourceFrame(
      loading: state.loading,
      error: state.error,
      onRetry: controller.reload,
      header: [
        Text(
          l.tournamentManageSponsors,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        FilledButton.icon(
          onPressed: state.busy || !state.loaded
              ? null
              : () => openResourceEditor(
                  context,
                  TournamentSponsorEditor(tournamentId: tournamentId),
                ),
          icon: const Icon(Icons.add),
          label: Text(l.tournamentResourceAdd),
        ),
      ],
      children: [
        if (items.isEmpty && !state.loading)
          ListTile(title: Text(l.tournamentResourceEmpty)),
        for (final sponsor in items)
          Card(
            child: ListTile(
              leading: sponsor.logo?.isNotEmpty == true
                  ? SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.network(
                        sponsor.logo!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_not_supported),
                      ),
                    )
                  : null,
              title: Text(sponsor.name),
              subtitle: Text(
                '${sponsor.displayOrder} · ${sponsor.website ?? ''}',
              ),
              onTap: state.busy
                  ? null
                  : () => openResourceEditor(
                      context,
                      TournamentSponsorEditor(
                        tournamentId: tournamentId,
                        sponsor: sponsor,
                      ),
                    ),
              trailing: IconButton(
                tooltip: l.commonDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: state.busy
                    ? null
                    : () async {
                        if (await confirmResourceDelete(
                          context,
                          sponsor.name,
                        )) {
                          await controller.delete(sponsor.id);
                        }
                      },
              ),
            ),
          ),
      ],
    );
  }
}
