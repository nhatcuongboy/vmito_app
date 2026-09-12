import 'package:flutter/material.dart';
import 'package:vmito_app/shared/models/court.dart';

/// The court itself: surface colour, boundary, service lines and the net.
///
/// Geometry ported from `vmito-fe/src/components/court/BadmintonCourt.tsx`,
/// which draws the same lines as absolutely-positioned boxes.
class CourtSurfacePainter extends CustomPainter {
  const CourtSurfacePainter({
    required this.status,
    this.courtColor,
    this.isDark = false,
  });

  final CourtStatus status;

  /// The host's chosen surface colour. Only an IN_USE court uses it — a READY
  /// court goes amber and an empty one grey, because status has to survive a
  /// host who picked a green that looks like every other green.
  final Color? courtColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);

    final borderWidth = isDark ? 2.0 : 3.0;
    final outerBorder = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRect(
      Rect.fromLTWH(
        borderWidth / 2,
        borderWidth / 2,
        size.width - borderWidth,
        size.height - borderWidth,
      ),
      outerBorder,
    );

    final lineAlpha = isDark && status == CourtStatus.empty ? 0.5 : 0.9;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: lineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas
      ..drawRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), line)
      // Centre service line, running the length of the court.
      ..drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        line,
      )
      // Back service lines.
      ..drawLine(
        Offset(size.width * .1, 0),
        Offset(size.width * .1, size.height),
        line,
      )
      ..drawLine(
        Offset(size.width * .9, 0),
        Offset(size.width * .9, size.height),
        line,
      )
      // Doubles sidelines.
      ..drawLine(
        Offset(0, size.height * .08),
        Offset(size.width, size.height * .08),
        line,
      )
      ..drawLine(
        Offset(0, size.height * .92),
        Offset(size.width, size.height * .92),
        line,
      )
      // Short service lines, either side of the net.
      ..drawLine(
        Offset(size.width * .4, 0),
        Offset(size.width * .4, size.height),
        line,
      )
      ..drawLine(
        Offset(size.width * .6, 0),
        Offset(size.width * .6, size.height),
        line,
      );

    _paintNet(canvas, size);
  }

  /// A dashed vertical line down the middle.
  void _paintNet(Canvas canvas, Size size) {
    final netAlpha = isDark && status == CourtStatus.empty ? 0.55 : 1.0;
    final net = Paint()
      ..color = Colors.white.withValues(alpha: netAlpha)
      ..strokeWidth = 2;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + 4).clamp(0, size.height)),
        net,
      );
    }
  }

  // Dark-mode empty/ready fills reuse the exact tones CourtSlotPlaceholder
  // uses for its inactive/active circles — a court and its seats read as one
  // surface instead of drifting apart. Both sit visibly above the card's
  // near-black background (AppColors.cardDark, `0xFF1C1917`); the previous
  // `0xff18181b` was close enough in luminance to disappear into it.
  Color get _background => switch (status) {
    CourtStatus.inUse => courtColor ?? const Color(0xff179a3b),
    CourtStatus.ready =>
      isDark ? const Color(0xFF422006) : const Color(0xfffef3c7),
    CourtStatus.empty =>
      isDark ? const Color(0xFF27272A) : const Color(0xffe6e6e6),
  };

  Color get _borderColor => switch (status) {
    CourtStatus.ready =>
      isDark
          ? const Color(0xFFEAB308) // yellow.500, solid — matches the slot dot
          : const Color(0xfffacc15), // yellow.400
    CourtStatus.inUse =>
      isDark
          ? const Color(0x4dffffff) // whiteAlpha.300 — same as light
          : const Color(0x4dffffff), // whiteAlpha.300
    CourtStatus.empty =>
      isDark
          ? const Color(0xFF52525B) // zinc.600 — same as the slot dot
          : const Color(0xffe4e4e7), // border
  };

  @override
  bool shouldRepaint(CourtSurfacePainter oldDelegate) =>
      oldDelegate.status != status ||
      oldDelegate.courtColor != courtColor ||
      oldDelegate.isDark != isDark;
}
