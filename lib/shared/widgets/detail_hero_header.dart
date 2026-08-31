import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_typography.dart';

/// Shared controls and spacing for detail headers that sit over a hero image.
abstract final class DetailHeroHeader {
  static const coverActionBackground = Color(0xB8000000);
  static const actionButtonSize = 36.0;
  static const actionIconSize = 18.0;
  static const backButtonSize = 40.0;
  static const backIconSize = 24.0;
  static const leadingWidth = 64.0;
  static const leadingPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: AppSpacing.xs,
  );
  static const actionsPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm + 4,
  );

  static TextStyle titleStyle(TextTheme textTheme) =>
      AppTypography.compactAppBarTitle(
        textTheme,
      ).copyWith(fontSize: 16, height: 20 / 16);
}

/// A circular hero-header control with a separately sized visual and hit area.
class DetailHeroHeaderButton extends StatelessWidget {
  const DetailHeroHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.pinned,
    required this.onPressed,
    this.size = DetailHeroHeader.actionButtonSize,
    this.hitTargetSize,
    this.visualKey,
    this.iconSize = DetailHeroHeader.actionIconSize,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool pinned;
  final VoidCallback onPressed;
  final double size;
  final double? hitTargetSize;
  final Key? visualKey;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final targetSize = hitTargetSize ?? size;

    return IconButton(
      tooltip: tooltip,
      icon: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          key: visualKey,
          decoration: BoxDecoration(
            color: pinned
                ? Colors.transparent
                : DetailHeroHeader.coverActionBackground,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: pinned ? null : Colors.white,
            ),
          ),
        ),
      ),
      style: IconButton.styleFrom(
        minimumSize: Size.square(targetSize),
        maximumSize: Size.square(targetSize),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }
}
