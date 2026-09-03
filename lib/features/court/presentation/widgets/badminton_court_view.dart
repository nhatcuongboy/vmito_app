import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_player_marker.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_player_tooltip.dart';
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
class BadmintonCourtView extends StatefulWidget {
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
  State<BadmintonCourtView> createState() => _BadmintonCourtViewState();
}

class _BadmintonCourtViewState extends State<BadmintonCourtView> {
  OverlayEntry? _tooltipEntry;
  int? _activeTooltipSeat;
  final Map<int, GlobalKey> _seatKeys = {};
  ScrollPosition? _scrollPosition;

  GlobalKey _getSeatKey(int seat) =>
      _seatKeys.putIfAbsent(seat, () => GlobalKey());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScrollListener();
  }

  void _updateScrollListener() {
    final newPosition = Scrollable.maybeOf(context)?.position;
    if (newPosition != _scrollPosition) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScrollChanged);
      _scrollPosition = newPosition;
      _scrollPosition?.isScrollingNotifier.addListener(_onScrollChanged);
    }
  }

  void _onScrollChanged() {
    if (_scrollPosition?.isScrollingNotifier.value == true) {
      _hideTooltip();
    }
  }

  @override
  void didUpdateWidget(BadmintonCourtView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.court.id != widget.court.id ||
        oldWidget.court.status != widget.court.status ||
        oldWidget.court.currentPlayers != widget.court.currentPlayers) {
      _hideTooltip();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollChanged);
    _hideTooltip();
    super.dispose();
  }

  void _hideTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
    _activeTooltipSeat = null;
  }

  void _handlePlayerTap(int seat, SessionPlayer player, int pairNumber) {
    if (_activeTooltipSeat == seat) {
      _hideTooltip();
      return;
    }

    _hideTooltip();

    final seatContext = _seatKeys[seat]?.currentContext;
    if (seatContext == null || !seatContext.mounted) return;
    final box = seatContext.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final targetRect = box.localToGlobal(Offset.zero) & box.size;

    _activeTooltipSeat = seat;
    _tooltipEntry = OverlayEntry(
      builder: (context) => CourtPlayerTooltipOverlay(
        player: player,
        pairNumber: pairNumber,
        targetRect: targetRect,
        onDismiss: _hideTooltip,
      ),
    );
    Overlay.of(context).insert(_tooltipEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final format = _format;
    final seats = _seats(format);
    final direction = widget.court.direction == CourtDirection.vertical
        ? PairDirection.vertical
        : PairDirection.horizontal;

    return Semantics(
      label: AppLocalizations.of(context).courtName(widget.court),
      child: AspectRatio(
        aspectRatio: AppSizes.courtAspectRatio,
        child: CustomPaint(
          painter: CourtSurfacePainter(
            status: widget.court.status,
            courtColor: widget.courtColor,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return Stack(
                children: [
                  for (var seat = 0; seat < seats.length; seat++)
                    () {
                      final visualIndex = CourtSlotLayout.visualIndexOf(
                        seat,
                        direction,
                        format,
                      );
                      final offset = CourtSlotLayout.offsetAt(
                        visualIndex,
                        format,
                      );
                      return Positioned(
                        left: width * offset.dx,
                        top: height * offset.dy,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: KeyedSubtree(
                            key: _getSeatKey(seat),
                            child: _seatChild(
                              context,
                              seat,
                              seats[seat],
                              CourtSlotLayout.pairNumberFor(visualIndex),
                            ),
                          ),
                        ),
                      );
                    }(),
                  ...widget.overlays,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _seatChild(
    BuildContext context,
    int seat,
    SessionPlayer? player,
    int pairNumber,
  ) {
    if (player == null) {
      // Only selection mode draws empty seats; elsewhere a gap is just a gap.
      if (!widget.mode.isSelection) return const SizedBox.shrink();
      return CourtSlotPlaceholder(
        slotNumber: seat + 1,
        isActive: seat == widget.activeSlot,
        onTap: widget.onSlotTap == null ? null : () => widget.onSlotTap!(seat),
      );
    }

    return CourtPlayerMarker(
      player: player,
      mode: widget.mode,
      displayMode: widget.displayMode,
      pairNumber: pairNumber,
      isActive: widget.mode.isSelection && seat == widget.activeSlot,
      onTap: () {
        if (widget.mode.isSelection && widget.onSlotTap != null) {
          widget.onSlotTap!(seat);
        } else {
          _handlePlayerTap(seat, player, pairNumber);
        }
      },
    );
  }

  CourtFormat get _format {
    final type = widget.matchType ?? widget.court.matchTypeOr(MatchType.doubles);
    return type == MatchType.singles
        ? CourtFormat.singles
        : CourtFormat.doubles;
  }

  /// Seat index → occupant. Selection state wins; otherwise the court's own
  /// players, falling back to the pre-selected line-up on an empty court.
  List<SessionPlayer?> _seats(CourtFormat format) {
    final slots = List<SessionPlayer?>.filled(
      CourtSlotLayout.slotCount(format),
      null,
    );

    if (widget.selection != null) {
      for (
        var seat = 0;
        seat < slots.length && seat < widget.selection!.length;
        seat++
      ) {
        slots[seat] = widget.selection![seat];
      }
      return slots;
    }

    final occupants = widget.court.currentPlayers.isNotEmpty
        ? widget.court.currentPlayers
        : widget.preSelectedPlayers;

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
