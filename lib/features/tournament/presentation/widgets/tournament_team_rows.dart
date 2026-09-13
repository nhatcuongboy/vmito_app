import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/web/app_web_view.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/tournament/domain/tournament_teams.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Player and team detail pages have no native port yet, so rows open the
/// web pages (`/t/{slug}/p/{code}`, `/t/{slug}/team/{code}`).
void openTournamentTeamPage(
  BuildContext context, {
  required String slug,
  required String code,
  required TournamentTeamTarget target,
  required String title,
}) {
  final language = Localizations.localeOf(context).languageCode;
  final path = Uri(
    pathSegments: [
      '',
      if (language == 'zh') 'cn' else language,
      't',
      slug,
      if (target == TournamentTeamTarget.team) 'team' else 'p',
      code,
    ],
  ).toString();
  unawaited(
    AppWebView.open(
      context,
      ProviderScope.containerOf(context),
      AppWebPage(path: path, title: title),
    ),
  );
}

class TournamentTeamPlayerTile extends StatelessWidget {
  const TournamentTeamPlayerTile({
    required this.player,
    required this.slug,
    super.key,
  });

  final TournamentTeamPlayer player;
  final String slug;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: ListTile(
      leading: UserAvatar(name: player.name, imageUrl: player.image, size: 44),
      title: Text(
        player.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: player.categories.isEmpty
          ? null
          : Text(
              player.categories.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () => openTournamentTeamPage(
        context,
        slug: slug,
        code: player.code,
        target: TournamentTeamTarget.player,
        title: player.name,
      ),
    ),
  );
}

class TournamentTeamCategoryCard extends StatelessWidget {
  const TournamentTeamCategoryCard({
    required this.category,
    required this.slug,
    super.key,
  });

  final TournamentTeamCategory category;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      l10n.tournamentTeamsCount(category.rows.length),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (category.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.tournamentTeamsNoTeams),
            )
          else
            for (final row in category.rows) _TeamRowTile(row: row, slug: slug),
        ],
      ),
    );
  }
}

class _TeamRowTile extends StatelessWidget {
  const _TeamRowTile({required this.row, required this.slug});

  final TournamentTeamRow row;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = row.name ?? l10n.tournamentTeamsUnknown;
    final code = row.code;
    final target = row.target;
    return ListTile(
      leading: Icon(
        target == TournamentTeamTarget.player ? AppIcons.user : AppIcons.users,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: row.members.isEmpty
          ? null
          : Text(
              row.members.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: code == null ? null : const Icon(AppIcons.chevronRight),
      onTap: code == null || target == null
          ? null
          : () => openTournamentTeamPage(
              context,
              slug: slug,
              code: code,
              target: target,
              title: name,
            ),
    );
  }
}
