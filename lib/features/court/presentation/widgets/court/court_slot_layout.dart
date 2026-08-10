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
  /// bottom-right. Fractions of the court box, converted to [Alignment].
  static const _doubles = <Alignment>[
    Alignment(-0.5, -0.4), // 25% / 30%
    Alignment(0.5, -0.4), // 75% / 30%
    Alignment(-0.5, 0.44), // 25% / 72%
    Alignment(0.5, 0.44), // 75% / 72%
  ];

  static const _singles = <Alignment>[
    Alignment(-0.5, 0), // 25% / 50%
    Alignment(0.5, 0), // 75% / 50%
  ];

  /// How many squares a format draws.
  static int slotCount(CourtFormat format) => format.playerCount;

  /// The square [visualIndex] is drawn in.
  static Alignment alignmentAt(int visualIndex, CourtFormat format) {
    final squares = format == CourtFormat.singles ? _singles : _doubles;
    return squares[visualIndex.clamp(0, squares.length - 1)];
  }

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
