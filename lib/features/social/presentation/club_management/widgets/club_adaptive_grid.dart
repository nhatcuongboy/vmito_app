import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// One column on phones; on tablets, as many columns as fit [maxExtent].
class ClubAdaptiveGrid extends StatelessWidget {
  const ClubAdaptiveGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.maxExtent = 440,
    this.gap = 12,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double maxExtent;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width < 600) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < itemCount; i++) ...[
              if (i > 0) SizedBox(height: gap),
              itemBuilder(context, i),
            ],
          ],
        );
      }
      final columns = (width / maxExtent).ceil().clamp(1, 4);
      final itemWidth = (width - (columns - 1) * AppSpacing.md) / columns;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (var i = 0; i < itemCount; i++)
            SizedBox(width: itemWidth, child: itemBuilder(context, i)),
        ],
      );
    },
  );
}
