import 'package:flutter/material.dart';
import 'package:vmito_app/shared/models/court.dart';

/// The court itself: surface colour, boundary, service lines and the net.
///
/// Geometry ported from `vmito-fe/src/components/court/BadmintonCourt.tsx`,
/// which draws the same lines as absolutely-positioned boxes.
class CourtSurfacePainter extends CustomPainter {
  const CourtSurfacePainter({required this.status, this.courtColor});

  final CourtStatus status;

  /// The host's chosen surface colour. Only an IN_USE court uses it — a READY
  /// court goes amber and an empty one grey, because status has to survive a
  /// host who picked a green that looks like every other green.
  final Color? courtColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
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
    final net = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + 4).clamp(0, size.height)),
        net,
      );
    }
  }

  Color get _background => switch (status) {
    CourtStatus.inUse => courtColor ?? const Color(0xff16834c),
    CourtStatus.ready => const Color(0xffc59318),
    CourtStatus.empty => const Color(0xffe6e6e6),
  };

  @override
  bool shouldRepaint(CourtSurfacePainter oldDelegate) =>
      oldDelegate.status != status || oldDelegate.courtColor != courtColor;
}
