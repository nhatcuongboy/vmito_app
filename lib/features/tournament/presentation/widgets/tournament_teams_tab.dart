import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_teams_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_teams.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_team_rows.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Native port of the web shell's Teams tab (`/tournament/[id]/teams`).
///
/// The web persists the view mode in `?view=`; here it is local tab state,
/// since the shell's URL only carries which tab is open.
class TournamentTeamsTab extends ConsumerStatefulWidget {
  const TournamentTeamsTab({required this.idOrSlug, super.key});

  final String idOrSlug;

  @override
  ConsumerState<TournamentTeamsTab> createState() => _TournamentTeamsTabState();
}

class _TournamentTeamsTabState extends ConsumerState<TournamentTeamsTab> {
  // Matches the web default: the all-players view opens first.
  bool _byCategory = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = tournamentTeamsControllerProvider(widget.idOrSlug);
    final teams = ref.watch(provider);
    return teams.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorView(
        error: error,
        onRetry: () => ref.invalidate(provider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: ref.read(provider.notifier).refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _header(context),
            const SizedBox(height: AppSpacing.md),
            if (_byCategory)
              ..._categoryView(context, data)
            else
              ..._playersView(context, data),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canManage =
        ref
            .watch(tournamentManageAccessProvider(widget.idOrSlug))
            .value
            ?.canManage ??
        false;
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(AppIcons.users),
                label: Text(l10n.tournamentTeamsAllPlayers),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(AppIcons.grid),
                label: Text(l10n.tournamentTeamsByCategory),
              ),
            ],
            selected: {_byCategory},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _byCategory = value.first),
          ),
        ),
        if (canManage) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            tooltip: l10n.tournamentTeamsManage,
            icon: const Icon(AppIcons.edit),
            onPressed: () => unawaited(
              context.push(
                AppRoutes.manageTournament(widget.idOrSlug, option: 'teams'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _playersView(BuildContext context, TournamentTeams data) {
    final l10n = AppLocalizations.of(context);
    final players = data.players.where((p) => p.matches(_query)).toList();
    return [
      TextField(
        decoration: InputDecoration(
          hintText: l10n.tournamentTeamsSearch,
          prefixIcon: const Icon(AppIcons.search),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(l10n.tournamentTeamsPlayersCount(players.length)),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (players.isEmpty)
        _Empty(text: l10n.tournamentTeamsNoPlayers)
      else
        for (final player in players)
          TournamentTeamPlayerTile(player: player, slug: _slug),
    ];
  }

  List<Widget> _categoryView(BuildContext context, TournamentTeams data) {
    if (data.categories.isEmpty) {
      return [
        _Empty(text: AppLocalizations.of(context).tournamentTeamsNoCategories),
      ];
    }
    return [
      for (final category in data.categories)
        TournamentTeamCategoryCard(category: category, slug: _slug),
    ];
  }

  String get _slug =>
      ref
          .watch(tournamentDetailControllerProvider(widget.idOrSlug))
          .value
          ?.tournament
          .slug ??
      widget.idOrSlug;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Text(text, textAlign: TextAlign.center),
  );
}
