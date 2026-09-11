import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Responsive grid chrome for a row of `SessionStatCard`s: 2 columns under
/// 680px, 4 columns at or above it. Callers supply the stat cards.
class SessionStatsGrid extends StatelessWidget {
  const SessionStatsGrid({
    required this.maxWidth,
    required this.children,
    super.key,
  });
  final double maxWidth;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final columns = maxWidth >= 680 ? 4 : 2;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: columns == 2 ? 1.3 : 1.35,
      children: children,
    );
  }
}
