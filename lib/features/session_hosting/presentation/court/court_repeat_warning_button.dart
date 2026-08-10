import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/court/application/match_repeat_warning_adapter.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_overlay_buttons.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/match_repeat_warning_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Shows a ⚠ over the court when its line-up repeats an old pairing.
///
/// Renders nothing when there is no warning, so an unremarkable court stays
/// clean. Match history is fetched once per session and shared across courts.
class CourtRepeatWarningButton extends ConsumerWidget {
  const CourtRepeatWarningButton({
    required this.session,
    required this.court,
    super.key,
  });

  final Session session;
  final Court court;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider(session.id)).asData?.value;
    // No history yet, or still loading: nothing can be a repeat.
    if (history == null || history.isEmpty) return const SizedBox.shrink();

    final courtsById = {for (final c in session.courts) c.id: c};
    final warning = getMatchRepeatWarning(
      [
        for (final match in history)
          toPlayedMatch(
            match,
            // The court it was played on, not this one — teams were decided by
            // that court's geometry.
            direction:
                courtsById[match.courtId]?.direction ??
                CourtDirection.horizontal,
          ),
      ],
      toPositionedPlayers(
        // Seats, in slot order, as the court itself is drawn.
        [
          for (final id in court.orderedPlayerIds)
            court.currentPlayers.where((p) => p.id == id).firstOrNull,
        ],
      ),
      direction: court.direction.asPairDirection,
      format: court.matchTypeOr(session.defaultMatchType).asCourtFormat,
    );

    if (!warning.hasWarning) return const SizedBox.shrink();

    final palette = Theme.of(context).extension<AppPalette>()!;
    return CourtOverlayButton(
      key: const ValueKey('court-repeat-warning'),
      icon: AppIcons.warning,
      tooltip: AppLocalizations.of(context).matchRepeatOpenDetails,
      background: palette.warning,
      foreground: Colors.black87,
      onPressed: () => showMatchRepeatWarningSheet(context, warning: warning),
    );
  }
}
