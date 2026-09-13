import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_schedule_screen.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_standings_screen.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_admin_panels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_categories_panel.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_panel.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_players_panel.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_settings_panels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_sponsors_panel.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_teams_panel.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The body of one manage menu option.
class TournamentManagePanel extends ConsumerWidget {
  const TournamentManagePanel({
    required this.idOrSlug,
    required this.tournament,
    required this.state,
    required this.option,
    this.initialCategoryId,
    super.key,
  });

  final String idOrSlug;
  final TournamentDetail tournament;
  final TournamentManagementState state;
  final String? option;
  final String? initialCategoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      tournamentManagementControllerProvider(idOrSlug).notifier,
    );
    void snack(String text, {bool error = false}) =>
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            backgroundColor: error ? Theme.of(context).colorScheme.error : null,
          ),
        );

    Future<void> update(Map<String, dynamic> changes) async {
      try {
        await controller.update(changes);
        if (context.mounted) snack(l10n.tournamentManageSaved);
      } on Object {
        if (context.mounted) {
          snack(l10n.tournamentManageSaveFailed, error: true);
        }
      }
    }

    return switch (option) {
      'categories' => TournamentCategoriesPanel(
        tournament: tournament,
        idOrSlug: idOrSlug,
      ),
      'teams' => TournamentTeamsPanel(
        tournament: tournament,
        idOrSlug: idOrSlug,
        initialCategoryId: initialCategoryId,
      ),
      'format' => TournamentFormatPanel(
        tournament: tournament,
        idOrSlug: idOrSlug,
        initialCategoryId: initialCategoryId,
      ),
      'players' => TournamentPlayersPanel(tournamentId: tournament.id),
      'sponsors' => TournamentSponsorsPanel(tournamentId: tournament.id),
      'status' => TournamentStatusPanel(
        tournament: tournament,
        busy: state.isMutating,
        onUpdate: update,
      ),
      'name' => TournamentNamePanel(
        key: ValueKey('name-${tournament.name}-${tournament.description}'),
        tournament: tournament,
        busy: state.isMutating,
        onUpdate: update,
      ),
      'dates' => TournamentDatesPanel(
        key: ValueKey('dates-${tournament.startDate}-${tournament.endDate}'),
        tournament: tournament,
        busy: state.isMutating,
        onUpdate: update,
      ),
      'visibility' => TournamentVisibilityPanel(
        key: ValueKey('visibility-${tournament.isPublished}'),
        tournament: tournament,
        busy: state.isMutating,
        onUpdate: update,
      ),
      'banner' => TournamentBannerPanel(
        key: ValueKey('banner-${tournament.coverPhoto}'),
        tournament: tournament,
        busy: state.isMutating,
        onUpdate: update,
        onUpload: (file) async => ref
            .read(tournamentManagementServiceProvider)
            .uploadImage(
              bytes: await file.readAsBytes(),
              filename: file.name,
              category: 'SESSION_COVER',
            ),
      ),
      'videos' => TournamentVideosPanel(
        key: ValueKey('videos-${tournament.youtubeVideoUrls.join(',')}'),
        tournament: tournament,
        busy: state.isMutating,
        onUpdate: update,
      ),
      'contact' => TournamentContactPanel(
        key: ValueKey(
          'contact-${tournament.contactName}-${tournament.contactEmail}-${tournament.contactPhone}',
        ),
        tournament: tournament,
        busy: state.isMutating,
        onUpdate: update,
      ),
      'managers' => TournamentManagersPanel(tournamentId: tournament.id),
      'duplicate' => TournamentDuplicatePanel(
        idOrSlug: idOrSlug,
        tournament: tournament,
      ),
      'delete' => TournamentDeletePanel(
        tournament: tournament,
        busy: state.isMutating,
        onDelete: () async {
          try {
            await controller.delete();
            if (context.mounted) {
              context.go(AppRoutes.homeForDiscoveryTab('tournaments'));
            }
          } on Object {
            if (context.mounted) {
              snack(l10n.tournamentManageSaveFailed, error: true);
            }
          }
        },
      ),
      // Embedded: the manage screen already owns the Scaffold and panel back
      // button, so the tab's own AppBar would stack a third header.
      'schedule' || 'results' => TournamentScheduleScreen(
        idOrSlug: idOrSlug,
        embedded: true,
      ),
      'standings' => TournamentStandingsScreen(
        idOrSlug: idOrSlug,
        embedded: true,
      ),
      null => const SizedBox.shrink(),
      _ => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.info, size: 42),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.tournamentManageComingSoon,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    };
  }
}
