import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// An empty, tappable square in selection mode.
///
/// Ports the placeholder branch of `BadmintonCourt.tsx`: a dashed circle
/// carrying its 1-based slot number, filled amber while it is the square the
/// next pick will land in.
class CourtSlotPlaceholder extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final accent = isActive ? palette.warning : Colors.white;

    return Semantics(
      button: true,
      selected: isActive,
      label: l10n.courtPositionNumber(slotNumber),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.35),
            shape: BoxShape.circle,
            // Icon plus fill, never colour alone: the active square also grows
            // its border, so it survives a monochrome display.
            border: Border.all(color: accent, width: isActive ? 3 : 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '$slotNumber',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.black87 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
