import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/web/app_web_view.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Web path of a tournament, as the web host list links it: by slug, with
/// the `/referee` console for REFEREE users.
String hostTournamentWebPath(
  BuildContext context,
  TournamentSummary tournament, {
  bool asReferee = false,
}) {
  final language = Localizations.localeOf(context).languageCode;
  final locale = language == 'zh' ? 'cn' : language;
  final segments = [
    locale,
    'tournament',
    tournament.slug ?? tournament.id,
    if (asReferee) 'referee',
  ];
  return '/${Uri(pathSegments: segments)}';
}

/// Opens the tournament in the in-app browser until its detail screens are
/// ported. Signed in, because the web shell only shows management tools to an
/// authenticated host, manager or umpire.
Future<void> openHostTournamentWeb(
  BuildContext context,
  TournamentSummary tournament, {
  bool asReferee = false,
}) => AppWebView.open(
  context,
  ProviderScope.containerOf(context),
  AppWebPage(
    path: hostTournamentWebPath(context, tournament, asReferee: asReferee),
    title: tournament.name,
    requiresAuth: true,
    embedded: true,
  ),
);

Future<void> shareHostTournament(
  BuildContext context,
  TournamentSummary tournament,
) async {
  final url =
      '${AppConfig.webBaseUrl}${hostTournamentWebPath(context, tournament)}';
  final box = context.findRenderObject();
  await SharePlus.instance.share(
    ShareParams(
      title: tournament.name,
      subject: AppLocalizations.of(context).tournamentDetailShareSubject,
      text: '${tournament.name}\n$url',
      sharePositionOrigin: box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    ),
  );
}
