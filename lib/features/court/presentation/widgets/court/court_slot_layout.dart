import 'package:flutter/widgets.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Where each court seat is drawn, and which seat lands where.
///
/// Ports the placeholder coordinates in
/// `vmito-fe/src/components/court/BadmintonCourt.tsx`.
///
/// **Direction is a coordinate transform, not a second layout** — one widget
/// tree, per `docs/PORTING_GUIDE.md`. The court is always drawn landscape with
/// the net vertical, so a *team* is always a column. What direction changes is
/// only which API seat number sits in which square.
abstract final class CourtSlotLayout {
  /// Visual squares in the web's order: top-left, top-right, bottom-left,
  /// bottom-right. Normalized (0..1) center coordinates matching the white court
  /// boundary boxes:
  /// - Left column: center at X = 25% (between 10% back service & 40% short service)
  /// - Right column: center at X = 75% (between 60% short service & 90% back service)
  /// - Top row: center at Y = 29% (between 8% doubles sideline & 50% centre line)
  /// - Bottom row: center at Y = 71% (between 50% centre line & 92% doubles sideline)
  static const _doublesOffsets = <Offset>[
    Offset(0.25, 0.29),
    Offset(0.75, 0.29),
    Offset(0.25, 0.71),
    Offset(0.75, 0.71),
  ];

  static const _singlesOffsets = <Offset>[
    Offset(0.25, 0.50),
    Offset(0.75, 0.50),
  ];

  /// Visual squares converted to [Alignment] (-1..1 range).
  static const _doubles = <Alignment>[
    Alignment(-0.5, -0.42), // 25% / 29%
    Alignment(0.5, -0.42), // 75% / 29%
    Alignment(-0.5, 0.42), // 25% / 71%
    Alignment(0.5, 0.42), // 75% / 71%
  ];

  static const _singles = <Alignment>[
    Alignment(-0.5, 0), // 25% / 50%
    Alignment(0.5, 0), // 75% / 50%
  ];

  /// How many squares a format draws.
  static int slotCount(CourtFormat format) => format.playerCount;

  /// The normalized offset [visualIndex] is centered at (0..1 range).
  static Offset offsetAt(int visualIndex, CourtFormat format) {
    final offsets = format == CourtFormat.singles
        ? _singlesOffsets
        : _doublesOffsets;
    return offsets[visualIndex.clamp(0, offsets.length - 1)];
  }

  /// The square [visualIndex] is drawn in.
  static Alignment alignmentAt(int visualIndex, CourtFormat format) {
    final squares = format == CourtFormat.singles ? _singles : _doubles;
    return squares[visualIndex.clamp(0, squares.length - 1)];
  }

  /// Which team a square belongs to: 1 for the left column, 2 for the right.
  ///
  /// Both `_doubles` and `_singles` list left-column squares at even indices
  /// (top-left, bottom-left, or the singles left square) and right-column
  /// squares at odd ones, so parity alone decides it — no format needed.
  static int pairNumberFor(int visualIndex) => visualIndex.isEven ? 1 : 2;

  /// Which square an API seat is drawn in.
  ///
  /// Singles maps straight through. Doubles uses `visualSlotOrder`, which is
  /// `[0, 2, 1, 3]` for horizontal — seat 1 is drawn *third*, bottom-left, so
  /// that seats 0 and 1 share the left column and read as one team.
  ///
  /// The mapping is an involution, so the same table converts either way.
  static int visualIndexOf(
    int seat,
    PairDirection direction,
    CourtFormat format,
  ) {
    if (format == CourtFormat.singles) return seat.clamp(0, 1);
    final order = visualSlotOrder(direction);
    return seat >= 0 && seat < order.length ? order[seat] : 0;
  }

  /// Which API seat is drawn in a given square. Inverse of [visualIndexOf].
  static int seatAt(
    int visualIndex,
    PairDirection direction,
    CourtFormat format,
  ) => visualIndexOf(visualIndex, direction, format);
}
