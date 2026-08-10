import 'dart:ui';

abstract final class ProfileHeaderGeometry {
  static const double minCoverHeight = 140;
  static const double maxCoverHeight = 190;
  static const double collapsedHeight = 56;
  static const double maxStretchScale = 1.15;

  static double coverHeightForWidth(double screenWidth) =>
      (screenWidth / 2.5).clamp(minCoverHeight, maxCoverHeight);

  static double collapseProgress(double scrollOffset, double screenWidth) =>
      (scrollOffset / collapseExtent(screenWidth)).clamp(0, 1);

  static double visibleHeight(double scrollOffset, double screenWidth) =>
      lerpDouble(
        coverHeightForWidth(screenWidth),
        collapsedHeight,
        collapseProgress(scrollOffset, screenWidth),
      )!;

  static double expandedIdentityOpacity(
    double scrollOffset,
    double screenWidth,
  ) {
    final extent = collapseExtent(screenWidth);
    final fadeStart = extent * .7;
    final fadeProgress = ((scrollOffset - fadeStart) / (extent - fadeStart))
        .clamp(0.0, 1.0);
    return 1 - fadeProgress;
  }

  static double compactIdentityOpacity(
    double scrollOffset,
    double screenWidth,
  ) => 1 - expandedIdentityOpacity(scrollOffset, screenWidth);

  static double stretchScale(double overscroll, double screenWidth) {
    final coverHeight = coverHeightForWidth(screenWidth);
    return (1 + (-overscroll).clamp(0, coverHeight * .15) / coverHeight).clamp(
      1,
      maxStretchScale,
    );
  }

  static double collapseExtent(double screenWidth) =>
      coverHeightForWidth(screenWidth) - collapsedHeight;
}
