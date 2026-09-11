import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

@Preview(
  name: 'Social post card loading · Light',
  group: 'Social',
  size: Size(390, 460),
)
Widget socialPostCardSkeletonLightPreview() => _preview(AppTheme.light);

@Preview(
  name: 'Social post card loading · Dark',
  group: 'Social',
  size: Size(390, 460),
)
Widget socialPostCardSkeletonDarkPreview() => _preview(AppTheme.dark);

Widget _preview(ThemeData theme) => MaterialApp(
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: SocialPostCardSkeleton(showImage: true),
    ),
  ),
);

/// A loading placeholder that preserves the layout of a `SocialPostCard`.
///
/// The [Card] chrome and the divider above the action bar stay static; only the
/// avatar, text, image and action placeholders pulse. Paddings mirror the real
/// card's header (`16,14,8,0`), content (`16,10,16,0`) and action bar.
class SocialPostCardSkeleton extends StatelessWidget {
  const SocialPostCardSkeleton({this.showImage = false, super.key});

  final bool showImage;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    AppSkeletonBox(width: 40, height: 40, radius: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonBox(width: 140, height: 15),
                          SizedBox(height: 6),
                          AppSkeletonBox(width: 88, height: 11),
                        ],
                      ),
                    ),
                    AppSkeletonBox(width: 20, height: 6),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(height: 12),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeletonBox(width: 220, height: 12),
                  ],
                ),
              ),
              if (showImage)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: AppSkeletonBox(height: 180, radius: 0),
                ),
              const SizedBox(height: 14),
            ],
          ),
        ),
        const Divider(height: 1),
        const AppShimmer(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Row(
              children: [
                Expanded(child: _ActionPlaceholder()),
                Expanded(child: _ActionPlaceholder()),
                Expanded(child: _ActionPlaceholder()),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActionPlaceholder extends StatelessWidget {
  const _ActionPlaceholder();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      AppSkeletonBox(width: 18, height: 18, radius: 9),
      SizedBox(width: 6),
      AppSkeletonBox(width: 44, height: 12),
    ],
  );
}
