import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

@Preview(name: 'Feed loading · Light', group: 'Social', size: Size(390, 700))
Widget feedSkeletonLightPreview() => _preview(AppTheme.light);

@Preview(name: 'Feed loading · Dark', group: 'Social', size: Size(390, 700))
Widget feedSkeletonDarkPreview() => _preview(AppTheme.dark);

Widget _preview(ThemeData theme) => MaterialApp(
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(body: FeedSkeleton()),
);

/// Loading placeholder for the "Bảng tin" feed tab's first page of posts.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppSkeletonList(
    listKey: const Key('feed-skeleton-list'),
    itemBuilder: (_) => const SocialPostCardSkeleton(showImage: true),
    minItems: 2,
    maxItems: 5,
  );
}
