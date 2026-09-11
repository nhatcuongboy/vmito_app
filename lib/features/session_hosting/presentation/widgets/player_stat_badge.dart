import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Small pill chip used for categorical/scored table cells (gender, level,
/// win rate) so they scan faster than plain text in a dense table.
class PlayerStatBadge extends StatelessWidget {
  const PlayerStatBadge({required this.label, required this.color, super.key});
  final String label;
  final Color color;

  /// Chakra `pink.500` on web — there is no app-wide pink token, and this
  /// accent is only ever used for female-gender chips.
  static const pink = Color(0xFFEC4899);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs + 2,
      vertical: AppSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}
