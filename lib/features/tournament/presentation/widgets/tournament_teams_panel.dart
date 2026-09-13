import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/tournament/application/tournament_registrations_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_structure_refresh.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_team_roster.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_category_picker.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_team_add_sheet.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_team_editor.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Native port of vmito-fe `manage/panels/TeamsPanel.tsx`.
class TournamentTeamsPanel extends ConsumerStatefulWidget {
  const TournamentTeamsPanel({
    required this.tournament,
    required this.idOrSlug,
    this.initialCategoryId,
    super.key,
  });

  final TournamentDetail tournament;
  final String idOrSlug;
  final String? initialCategoryId;

  @override
  ConsumerState<TournamentTeamsPanel> createState() =>
      _TournamentTeamsPanelState();
}

class _TournamentTeamsPanelState extends ConsumerState<TournamentTeamsPanel> {
  late String? _categoryId = widget.initialCategoryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = widget.tournament.categories;
    final category = resolveSelectedCategory(categories, _categoryId);
    if (category == null) {
      return TournamentCategoryRequired(
        onAction: () => context.replace(
          AppRoutes.manageTournament(widget.idOrSlug, option: 'categories'),
        ),
      );
    }
    final isTeam = category.registrationMode == TournamentRegistrationMode.team;
    final key = (tournamentId: widget.tournament.id, categoryId: category.id);
    final state = ref.watch(tournamentRegistrationsProvider(key));
    final canEdit = state.loaded && !state.busy;
    return TournamentResourceFrame(
      loading: state.loading,
      // Mutation failures are reported by snackbar or in the editor; the frame
      // only shows load failures.
      error: state.loaded ? null : state.error,
      onRetry: ref.read(tournamentRegistrationsProvider(key).notifier).reload,
      header: [
        TournamentCategoryPicker(
          categories: categories,
          selected: category,
          onChanged: (value) => setState(() => _categoryId = value.id),
        ),
        FilledButton.icon(
          onPressed: canEdit ? () => _add(category) : null,
          icon: const Icon(AppIcons.add),
          label: Text(
            isTeam
                ? l10n.tournamentTeamsPanelTeamAdd
                : l10n.tournamentTeamsPanelPlayerAdd,
          ),
        ),
      ],
      children: [
        if (state.loaded && state.items.isEmpty)
          ListTile(
            title: Text(
              isTeam
                  ? l10n.tournamentTeamsPanelTeamEmpty
                  : l10n.tournamentTeamsPanelPlayerEmpty,
            ),
          ),
        for (final registration in state.items)
          Card(
            child: ListTile(
              title: Text(
                registration.displayName ?? l10n.tournamentTeamsUnknown,
              ),
              subtitle: isTeam ? _memberCount(registration, category) : null,
              onTap: canEdit ? () => _edit(category, registration) : null,
              trailing: IconButton(
                tooltip: l10n.commonDelete,
                icon: const Icon(AppIcons.delete),
                onPressed: canEdit
                    ? () => _remove(key, registration, isTeam: isTeam)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _memberCount(
    TournamentRegistration registration,
    TournamentCategory category,
  ) {
    final current = registration.memberIds.length;
    return Text(
      AppLocalizations.of(
        context,
      ).tournamentTeamsPanelMemberCount(current, category.teamSize),
      style: TextStyle(
        color: current < category.teamSize
            ? AppColors.warning
            : AppColors.success,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _add(TournamentCategory category) async {
    final added = await showTournamentTeamAddSheet(
      context,
      tournament: widget.tournament,
      category: category,
    );
    if (added && mounted) refreshTournamentStructure(ref, widget.idOrSlug);
  }

  Future<void> _edit(
    TournamentCategory category,
    TournamentRegistration registration,
  ) async {
    await openResourceEditor(
      context,
      TournamentTeamEditor(
        tournament: widget.tournament,
        category: category,
        registration: registration,
      ),
    );
    if (mounted) refreshTournamentStructure(ref, widget.idOrSlug);
  }

  Future<void> _remove(
    CategoryRegistrationsKey key,
    TournamentRegistration registration, {
    required bool isTeam,
  }) async {
    final name = registration.displayName ?? '';
    if (!await confirmResourceDelete(context, name)) return;
    final provider = tournamentRegistrationsProvider(key);
    final removed = await ref.read(provider.notifier).remove(registration.id);
    if (!mounted) return;
    if (removed) {
      refreshTournamentStructure(ref, widget.idOrSlug);
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${isTeam ? l10n.tournamentTeamsPanelTeamDeleteFailed : l10n.tournamentTeamsPanelPlayerDeleteFailed}: '
          '${resourceErrorMessage(context, ref.read(provider).error)}',
        ),
      ),
    );
  }
}
