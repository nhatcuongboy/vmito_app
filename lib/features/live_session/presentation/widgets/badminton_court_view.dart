import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/court.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Read-only live court board matching the web court's 13.4:6.1 geometry.
///
/// Direction changes only the player coordinate mapping. The painted court is
/// one widget tree, avoiding divergent horizontal/vertical implementations.
class BadmintonCourtView extends StatelessWidget {
  const BadmintonCourtView({required this.court, super.key});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final players = court.currentPlayers.isNotEmpty
        ? court.currentPlayers
        : court.preSelectedPlayers;

    return Semantics(
      label: AppLocalizations.of(context).courtName(court),
      child: AspectRatio(
        aspectRatio: AppSizes.courtAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: LayoutBuilder(
            builder: (context, constraints) => CustomPaint(
              painter: _CourtPainter(status: court.status),
              child: Stack(
                children: [
                  for (
                    var index = 0;
                    index < players.length && index < 4;
                    index++
                  )
                    _PlayerMarker(
                      player: players[index],
                      position: _position(
                        index,
                        players.length,
                        court.direction,
                      ),
                      courtSize: constraints.biggest,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Alignment _position(int index, int count, CourtDirection direction) {
    if (count <= 2) {
      return index == 0 ? const Alignment(-.52, 0) : const Alignment(.52, 0);
    }
    const quadrants = <Alignment>[
      Alignment(-.52, -.46),
      Alignment(-.52, .46),
      Alignment(.52, -.46),
      Alignment(.52, .46),
    ];
    // Web HORIZONTAL maps API order [0, 2, 1, 3].
    const horizontalMap = <int>[0, 2, 1, 3];
    return quadrants[direction == CourtDirection.horizontal
        ? horizontalMap[index]
        : index];
  }
}

class _PlayerMarker extends StatelessWidget {
  const _PlayerMarker({
    required this.player,
    required this.position,
    required this.courtSize,
  });

  final SessionPlayer player;
  final Alignment position;
  final Size courtSize;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: position,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: courtSize.width * .3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text(
              AppLocalizations.of(context).playerName(player),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourtPainter extends CustomPainter {
  const _CourtPainter({required this.status});

  final CourtStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    final background = switch (status) {
      CourtStatus.inUse => const Color(0xff16834c),
      CourtStatus.ready => const Color(0xffc59318),
      CourtStatus.empty => const Color(0xff667085),
    };
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas
      ..drawRect(rect, line)
      ..drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        line,
      )
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

    final net = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 7) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + 4).clamp(0, size.height)),
        net,
      );
    }
  }

  @override
  bool shouldRepaint(_CourtPainter oldDelegate) => oldDelegate.status != status;
}
