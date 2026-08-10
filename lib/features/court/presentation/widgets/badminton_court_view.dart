import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_player_marker.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_slot_layout.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_slot_placeholder.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_surface_painter.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// The court board, in all three modes.
///
/// Ports `vmito-fe/src/components/court/BadmintonCourt.tsx` (767 lines) as a
/// shell over four small widgets, rather than transliterating it — see the
/// hard rule in CLAUDE.md on React components over ~600 lines.
///
/// Direction is a **coordinate transform on one widget tree**, never a second
/// layout: see [CourtSlotLayout].
class BadmintonCourtView extends StatelessWidget {
  const BadmintonCourtView({
    required this.court,
    this.preSelectedPlayers = const [],
    this.mode = CourtViewMode.display,
    this.displayMode = CourtDisplayMode.name,
    this.matchType,
    this.courtColor,
    this.selection,
    this.activeSlot,
    this.onSlotTap,
    this.overlays = const [],
    super.key,
  });

  final Court court;

  /// Resolved pre-selected players — see `Session.preSelectedPlayersFor`.
  /// Drawn only when the court itself is empty.
  final List<SessionPlayer> preSelectedPlayers;

  final CourtViewMode mode;
  final CourtDisplayMode displayMode;

  /// Overrides the type inferred from the court's occupancy. The selection
  /// sheet needs this: an empty court has nothing to infer from.
  final MatchType? matchType;

  /// The session's court colour. Only an IN_USE court shows it.
  final Color? courtColor;

  /// Selection mode only: seat index → player, with gaps for empty seats.
  final List<SessionPlayer?>? selection;

  /// Selection mode only: the seat the next pick lands in.
  final int? activeSlot;

  /// Selection mode only. Fires with the **seat** index, not the visual one.
  final ValueChanged<int>? onSlotTap;

  /// Corner buttons — warning, announce. Stacked over the court.
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    final format = _format;
    final seats = _seats(format);
    final direction = court.direction == CourtDirection.vertical
        ? PairDirection.vertical
        : PairDirection.horizontal;

    return Semantics(
      label: AppLocalizations.of(context).courtName(court),
      child: AspectRatio(
        aspectRatio: AppSizes.courtAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: CustomPaint(
            painter: CourtSurfacePainter(
              status: court.status,
              courtColor: courtColor,
            ),
            child: Stack(
              children: [
                for (var seat = 0; seat < seats.length; seat++)
                  Align(
                    alignment: CourtSlotLayout.alignmentAt(
                      CourtSlotLayout.visualIndexOf(seat, direction, format),
                      format,
                    ),
                    child: _seatChild(context, seat, seats[seat]),
                  ),
                ...overlays,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seatChild(BuildContext context, int seat, SessionPlayer? player) {
    if (player == null) {
      // Only selection mode draws empty seats; elsewhere a gap is just a gap.
      if (!mode.isSelection) return const SizedBox.shrink();
      return CourtSlotPlaceholder(
        slotNumber: seat + 1,
        isActive: seat == activeSlot,
        onTap: onSlotTap == null ? null : () => onSlotTap!(seat),
      );
    }

    return ConstrainedBox(
      // Four names across a phone-width court will collide otherwise.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.28,
      ),
      child: CourtPlayerMarker(
        player: player,
        mode: mode,
        displayMode: displayMode,
        isActive: mode.isSelection && seat == activeSlot,
        // Tapping a filled seat in selection mode clears it and makes it the
        // active one, so a mis-tap is one tap to fix.
        onTap: onSlotTap == null ? null : () => onSlotTap!(seat),
      ),
    );
  }

  CourtFormat get _format {
    final type = matchType ?? court.matchTypeOr(MatchType.doubles);
    return type == MatchType.singles ? CourtFormat.singles : CourtFormat.doubles;
  }

  /// Seat index → occupant. Selection state wins; otherwise the court's own
  /// players, falling back to the pre-selected line-up on an empty court.
  List<SessionPlayer?> _seats(CourtFormat format) {
    final slots = List<SessionPlayer?>.filled(
      CourtSlotLayout.slotCount(format),
      null,
    );

    if (selection != null) {
      for (var seat = 0; seat < slots.length && seat < selection!.length; seat++) {
        slots[seat] = selection![seat];
      }
      return slots;
    }

    final occupants = court.currentPlayers.isNotEmpty
        ? court.currentPlayers
        : preSelectedPlayers;

    if (_seatsAreUsable(occupants, slots.length)) {
      for (final player in occupants) {
        slots[player.slotPosition] = player;
      }
      return slots;
    }

    // Seats that collide or fall outside the court mean the payload did not
    // carry usable positions. Placing everyone in slot 0 would hide three of
    // four players, so fall back to the order they arrived in — the arrangement
    // may be wrong, but nobody vanishes.
    for (var i = 0; i < occupants.length && i < slots.length; i++) {
      slots[i] = occupants[i];
    }
    return slots;
  }

  bool _seatsAreUsable(List<SessionPlayer> occupants, int slotCount) {
    final seen = <int>{};
    for (final player in occupants) {
      final seat = player.slotPosition;
      if (seat < 0 || seat >= slotCount) return false;
      if (!seen.add(seat)) return false;
    }
    return true;
  }
}
