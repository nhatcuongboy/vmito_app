import 'package:flutter/material.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// An empty, tappable square in selection mode.
///
/// Ports the placeholder branch of `BadmintonCourt.tsx`: a dashed circle
/// carrying its 1-based slot number, filled yellow while it is the active slot
/// (the next pick), or light grey otherwise. The active slot also shows a
/// pulsing outer ring matching the web's `currentPositionPulse` animation.
class CourtSlotPlaceholder extends StatefulWidget {
  const CourtSlotPlaceholder({
    required this.slotNumber,
    required this.isActive,
    this.onTap,
    super.key,
  });

  /// 1-based, as shown to the host.
  final int slotNumber;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  State<CourtSlotPlaceholder> createState() => _CourtSlotPlaceholderState();
}

class _CourtSlotPlaceholderState extends State<CourtSlotPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scale = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 0.7), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1), weight: 50),
    ]).animate(_pulse);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isActive = widget.isActive;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Active: yellow.100 bg, yellow.500 dashed border, yellow.700 text (light)
    //         dark amber bg, yellow.500 border, yellow.300 text (dark)
    // Inactive: gray.100 bg, gray.400 dashed border, gray.600 text (light)
    //           zinc.800 bg, zinc.600 border, zinc.400 text (dark)
    final bg = isActive
        ? (isDark ? const Color(0xFF422006) : const Color(0xFFFEF9C3))
        : (isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6));
    final borderColor = isActive
        ? const Color(0xFFEAB308)
        : (isDark ? const Color(0xFF52525B) : const Color(0xFF9CA3AF));
    final textColor = isActive
        ? (isDark ? const Color(0xFFFDE047) : const Color(0xFFB45309))
        : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF4B5563));

    final circle = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        '${widget.slotNumber}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );

    final child = isActive
        ? Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Pulsing outer ring — matches web's currentPositionPulse
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEAB308), // yellow.500
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              circle,
            ],
          )
        : circle;

    return Semantics(
      button: true,
      selected: isActive,
      label: l10n.courtPositionNumber(widget.slotNumber),
      child: GestureDetector(
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}
