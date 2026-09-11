import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_header_geometry.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_header_skeleton.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Loading placeholder for the first public-profile request.
///
/// Mirrors the loaded screen's geometry — responsive cover, avatar centred on
/// the cover edge, identity block starting 60dp below it, pinned tab bar, then
/// the default Posts tab — so nothing jumps when the data lands. The leading
/// menu/back button is real, not a placeholder: a slow request must not trap
/// the user without a way to open the drawer or leave.
class PublicProfileSkeleton extends StatelessWidget {
  const PublicProfileSkeleton({
    required this.isRootProfile,
    this.onMenuTap,
    super.key,
  });

  final bool isRootProfile;
  final VoidCallback? onMenuTap;

  /// Matches `_OverlayAvatar`: 44dp radius inside a 3dp white frame.
  static const _avatarRadius = 44.0;
  static const _avatarFrame = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final safeAreaTop = MediaQuery.paddingOf(context).top;
    final coverBottom =
        safeAreaTop +
        ProfileHeaderGeometry.coverHeightForWidth(
          MediaQuery.sizeOf(context).width,
        );
    // The placeholder cover is a light surface in light mode, so the loaded
    // header's white status-bar icons would disappear against it.
    final overlay = theme.brightness == Brightness.light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    final leadingColor = theme.colorScheme.onSurface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(statusBarColor: Colors.transparent),
      child: Stack(
        key: const Key('public-profile-skeleton'),
        fit: StackFit.expand,
        children: [
          Semantics(
            container: true,
            label: l10n.commonLoading,
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: coverBottom,
                          child: const _CoverPlaceholder(),
                        ),
                        const ProfileIdentitySkeleton(),
                        const ProfileTabBarSkeleton(),
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.screenPadding),
                          child: Column(
                            children: [
                              SocialPostCardSkeleton(),
                              SizedBox(height: 12),
                              SocialPostCardSkeleton(showImage: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: coverBottom - _avatarRadius - _avatarFrame,
                    left: 0,
                    right: 0,
                    child: const Center(child: _AvatarPlaceholder()),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: safeAreaTop,
            left: 0,
            width: kToolbarHeight,
            height: kToolbarHeight,
            child: Center(
              child: isRootProfile
                  ? IconButton(
                      tooltip: l10n.menuOpenTooltip,
                      onPressed: onMenuTap,
                      icon: Icon(AppIcons.menu, color: leadingColor),
                    )
                  : BackButton(color: leadingColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = skeletonPalette(theme);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.brandSurface,
                theme.colorScheme.surfaceContainerHighest,
                palette.muted,
              ],
            ),
          ),
        ),
        // Same curved content sheet the loaded cover ends with.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl + 4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('public-profile-skeleton-avatar'),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .16),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: const Padding(
      padding: EdgeInsets.all(PublicProfileSkeleton._avatarFrame),
      child: AppShimmer(
        child: AppSkeletonBox(
          width: PublicProfileSkeleton._avatarRadius * 2,
          height: PublicProfileSkeleton._avatarRadius * 2,
          radius: PublicProfileSkeleton._avatarRadius,
        ),
      ),
    ),
  );
}
