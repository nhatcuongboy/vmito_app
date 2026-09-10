import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Shared skeleton primitives.
///
/// Every feature used to re-implement its own `_SkeletonBox` + `Shimmer.fromColors`
/// with a barely-visible light-mode sweep (base `#F4F4F5` -> highlight `#FFFFFF`)
/// and an inverted dark-mode sweep. These three widgets define the shimmer look
/// once, keep the card chrome static so only the content pulses, and size the
/// loading list to the viewport instead of a fixed count.

/// Wraps [child] in the app's single tuned shimmer pass.
///
/// The highlight is derived from `onSurface` so the moving band stays visible in
/// light mode and sweeps light-over-dark in dark mode. Renders exactly one
/// [Shimmer]; keep only the content placeholders inside it, not the card border
/// or surface.
class AppShimmer extends StatelessWidget {
  const AppShimmer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Shimmer.fromColors(
      period: const Duration(milliseconds: 1450),
      baseColor: palette.muted,
      highlightColor: Color.alphaBlend(
        theme.colorScheme.onSurface.withValues(alpha: 0.10),
        palette.muted,
      ),
      child: child,
    );
  }
}

/// A single placeholder bar/box. Fill colour is irrelevant when placed inside an
/// [AppShimmer] (the shimmer overpaints it), so it stays a plain white box.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    this.width = double.infinity,
    this.height = double.infinity,
    this.radius = AppRadius.sm,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: SizedBox(width: width, height: height),
  );
}

/// A scrollable list of identical skeleton rows sized to fill the viewport.
///
/// The row count is `viewportHeight / itemExtentEstimate`, clamped to
/// [minItems]..[maxItems], so tall screens do not show blank space under a fixed
/// set of placeholders. Announces "loading" once for the whole list; individual
/// rows are [ExcludeSemantics].
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    required this.listKey,
    required this.itemBuilder,
    this.minItems = 3,
    this.maxItems = 8,
    this.itemExtentEstimate = 260,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.gap = AppSpacing.md,
    this.semanticsLabel,
    super.key,
  });

  /// Key placed on the inner [ListView] so tests can target the loading list.
  final Key listKey;

  /// Builds one placeholder row. Every row is identical, so the index is unused.
  final WidgetBuilder itemBuilder;

  final int minItems;
  final int maxItems;

  /// Rough rendered height of one row, used only to pick the row count.
  final double itemExtentEstimate;

  final EdgeInsetsGeometry padding;
  final double gap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel ?? AppLocalizations.of(context).commonLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxHeight;
          final itemCount = available.isFinite
              ? (available / itemExtentEstimate).ceil().clamp(
                  minItems,
                  maxItems,
                )
              : minItems;
          return ListView.separated(
            key: listKey,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            itemCount: itemCount,
            separatorBuilder: (_, _) => SizedBox(height: gap),
            itemBuilder: (context, _) =>
                ExcludeSemantics(child: itemBuilder(context)),
          );
        },
      ),
    );
  }
}
