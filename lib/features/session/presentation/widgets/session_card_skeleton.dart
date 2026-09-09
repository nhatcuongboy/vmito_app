import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A loading placeholder that preserves the layout of a [SessionCard].
///
/// Keep this scoped to session lists rather than using a generic loading box:
/// the fixed cover and information hierarchy avoid a noticeable layout shift
/// when loaded cards replace it.
class SessionCardSkeleton extends StatelessWidget {
  const SessionCardSkeleton({
    this.variant = SessionCardVariant.standard,
    this.showHostInfo = true,
    this.showFavorite = false,
    this.showActions = false,
    super.key,
  });

  final SessionCardVariant variant;
  final bool showHostInfo;
  final bool showFavorite;
  final bool showActions;

  static const _coverWidth = 108.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final isBrowse = variant == SessionCardVariant.browse;

    return Semantics(
      container: true,
      label: AppLocalizations.of(context).commonLoading,
      child: Shimmer.fromColors(
        baseColor: palette.muted,
        highlightColor: theme.colorScheme.surface,
        child: Card(
          color: isBrowse ? theme.colorScheme.surfaceContainerLowest : null,
          shape: isBrowse
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  side: BorderSide(color: palette.border),
                )
              : null,
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  width: _coverWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm + 2,
                      AppSpacing.sm + 2,
                      AppSpacing.sm + 2,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: _SkeletonBox(width: 136, height: 16),
                            ),
                            if (showFavorite) ...[
                              const SizedBox(width: AppSpacing.xs),
                              const _SkeletonBox(
                                key: Key('session-card-skeleton-favorite'),
                                width: 24,
                                height: 24,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (showHostInfo) ...[
                          const _SkeletonBox(
                            key: Key('session-card-skeleton-host'),
                            width: 104,
                            height: 12,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        const _SkeletonBox(width: 150, height: 12),
                        const SizedBox(height: AppSpacing.xs),
                        const _SkeletonBox(width: 172, height: 12),
                        const SizedBox(height: AppSpacing.sm),
                        const Row(
                          children: [
                            _SkeletonBox(width: 82, height: 22, radius: 12),
                            Spacer(),
                            _SkeletonBox(width: 48, height: 14),
                          ],
                        ),
                        if (isBrowse) ...[
                          const SizedBox(height: AppSpacing.xs),
                          const _SkeletonBox(width: 138, height: 18, radius: 8),
                        ],
                        if (showActions) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Divider(height: 1, color: palette.border),
                          const SizedBox(height: AppSpacing.sm),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SkeletonBox(width: 92, height: 40, radius: 12),
                                SizedBox(width: AppSpacing.xs),
                                _SkeletonBox(width: 40, height: 40, radius: 12),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width = double.infinity,
    this.height = double.infinity,
    this.radius = 999,
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
