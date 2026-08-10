import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/court/application/match_repeat_warning_adapter.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_overlay_buttons.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/match_repeat_warning_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// The ⚠ over the selection court, for a line-up not yet confirmed.
///
/// Separate from `CourtRepeatWarningButton` because the seats come from the
/// host's in-progress picks, not from the court's own players.
class CourtSelectionRepeatWarning extends ConsumerWidget {
  const CourtSelectionRepeatWarning({
    required this.sessionId,
    required this.court,
    required this.seats,
    required this.matchType,
    super.key,
  });

  final String sessionId;
  final Court court;

  /// Seat index → picked player, with gaps.
  final List<SessionPlayer?> seats;
  final MatchType matchType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider(sessionId)).asData?.value;
    if (history == null || history.isEmpty) return const SizedBox.shrink();

    final session = ref.watch(sessionDetailProvider(sessionId)).asData?.value;
    final courtsById = {
      for (final c in session?.courts ?? const <Court>[]) c.id: c,
    };

    final warning = getMatchRepeatWarning(
      [
        for (final match in history)
          toPlayedMatch(
            match,
            direction:
                courtsById[match.courtId]?.direction ??
                CourtDirection.horizontal,
          ),
      ],
      toPositionedPlayers(seats),
      direction: court.direction.asPairDirection,
      format: matchType.asCourtFormat,
    );

    if (!warning.hasWarning) return const SizedBox.shrink();

    final palette = Theme.of(context).extension<AppPalette>()!;
    return CourtOverlayButton(
      key: const ValueKey('selection-repeat-warning'),
      icon: AppIcons.warning,
      tooltip: AppLocalizations.of(context).matchRepeatOpenDetails,
      background: palette.warning,
      foreground: Colors.black87,
      onPressed: () => showMatchRepeatWarningSheet(context, warning: warning),
    );
  }
}
