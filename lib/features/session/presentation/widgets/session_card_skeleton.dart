import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

@Preview(
  name: 'Session browse card loading · Light',
  group: 'Sessions',
  size: Size(390, 260),
)
Widget sessionCardSkeletonLightPreview() => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: SessionCardSkeleton(
        variant: SessionCardVariant.browse,
        showFavorite: true,
      ),
    ),
  ),
);

@Preview(
  name: 'Session browse card loading · Dark',
  group: 'Sessions',
  size: Size(390, 260),
)
Widget sessionCardSkeletonDarkPreview() => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: SessionCardSkeleton(
        variant: SessionCardVariant.browse,
        showFavorite: true,
      ),
    ),
  ),
);

/// A loading placeholder that preserves the layout of a [SessionCard].
///
/// The [Card] chrome (border + surface) stays static; only the cover block and
/// the content bars pulse. The fixed cover width and information hierarchy avoid
/// a noticeable layout shift when loaded cards replace it.
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

    return Card(
      color: isBrowse ? theme.colorScheme.surfaceContainerLowest : null,
      shape: isBrowse
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              side: BorderSide(color: palette.border),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: AppShimmer(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                width: _coverWidth,
                child: AppSkeletonBox(radius: 0),
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
                            child: AppSkeletonBox(width: 136, height: 16),
                          ),
                          if (showFavorite) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const AppSkeletonBox(
                              key: Key('session-card-skeleton-favorite'),
                              width: 24,
                              height: 24,
                              radius: AppRadius.pill,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (showHostInfo) ...[
                        const Row(
                          children: [
                            AppSkeletonBox(
                              width: 14,
                              height: 14,
                              radius: AppRadius.pill,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            AppSkeletonBox(
                              key: Key('session-card-skeleton-host'),
                              width: 96,
                              height: 12,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      const AppSkeletonBox(width: 150, height: 12),
                      const SizedBox(height: AppSpacing.xs),
                      const AppSkeletonBox(width: 172, height: 12),
                      const SizedBox(height: AppSpacing.sm),
                      const Row(
                        children: [
                          AppSkeletonBox(width: 90, height: 14),
                          Spacer(),
                          AppSkeletonBox(width: 52, height: 12),
                        ],
                      ),
                      if (isBrowse) ...[
                        const SizedBox(height: AppSpacing.xs),
                        const AppSkeletonBox(
                          height: 8,
                          radius: AppRadius.pill,
                        ),
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
                              AppSkeletonBox(
                                width: 92,
                                height: 40,
                                radius: AppRadius.xl,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              AppSkeletonBox(
                                width: 40,
                                height: 40,
                                radius: AppRadius.xl,
                              ),
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
    );
  }
}
