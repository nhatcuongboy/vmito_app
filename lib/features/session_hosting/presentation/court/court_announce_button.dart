import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/notifications/court_call_effects.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/court/application/match_repeat_warning_adapter.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_overlay_buttons.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Reads a court's line-up aloud, so the gym hears who is up.
///
/// Ports the speaker button on `BadmintonCourt.tsx`, in the app's own locale
/// rather than the web's hardcoded `vi-VN`.
class CourtAnnounceButton extends ConsumerWidget {
  const CourtAnnounceButton({
    required this.court,
    required this.players,
    super.key,
  });

  final Court court;

  /// Who is on the court, in seat order.
  final List<SessionPlayer> players;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return CourtOverlayButton(
      alignment: Alignment.bottomRight,
      icon: AppIcons.volume,
      tooltip: l10n.courtAnnounceButton,
      foreground: Colors.white,
      onPressed: () => _announce(context, ref),
    );
  }

  Future<void> _announce(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final locale = ref.read(localeControllerProvider).languageCode;

    // A READY court is a call to come on; an IN_USE one is a statement of who
    // is already playing.
    final intro = court.status == CourtStatus.ready
        ? l10n.courtAnnounceReadyIntro
        : l10n.courtAnnouncePlayingIntro;

    await ref.read(courtCallEffectsProvider).announce([
      intro,
      l10n.courtAnnounceDetail(court.courtNumber, _names(l10n)),
    ], locale);
  }

  /// `An và Bình, Cường và Dũng` — teammates joined, sides separated.
  String _names(AppLocalizations l10n) {
    final groups = groupPairs([
      for (final player in players)
        PositionedPlayer(id: player.id, position: player.slotPosition),
    ], court.direction.asPairDirection);

    final byId = {for (final player in players) player.id: player};
    String join(List<PositionedPlayer> side) => side
        .map((seat) => l10n.playerName(byId[seat.id]!))
        .join(' ${l10n.courtAnnounceAnd} ');

    // An incomplete or malformed court still has to be announceable; read the
    // names straight through rather than saying nothing.
    if (groups == null) return players.map(l10n.playerName).join(', ');
    return '${join(groups.pair1)}, ${join(groups.pair2)}';
  }
}
