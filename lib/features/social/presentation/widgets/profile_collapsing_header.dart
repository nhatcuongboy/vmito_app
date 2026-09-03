import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vmito_app/core/constants/image_constants.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_typography.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_header_geometry.dart';

class ProfileCollapsingHeader extends StatelessWidget {
  const ProfileCollapsingHeader({
    required this.profile,
    required this.scrollOffset,
    required this.isRootProfile,
    required this.isOwner,
    required this.usesCompactSystemOverlay,
    required this.menuTooltip,
    required this.shareTooltip,
    required this.settingsTooltip,
    required this.changeCoverTooltip,
    required this.onMenuTap,
    required this.onShare,
    required this.onSettings,
    required this.coverProgress,
    required this.onChangeCover,
    required this.onViewCover,
    super.key,
  });

  final PublicProfile profile;
  final ValueListenable<double> scrollOffset;
  final bool isRootProfile;
  final bool isOwner;
  final bool usesCompactSystemOverlay;
  final String menuTooltip;
  final String shareTooltip;
  final String settingsTooltip;
  final String changeCoverTooltip;
  final VoidCallback onMenuTap;
  final VoidCallback onShare;
  final VoidCallback onSettings;
  final int? coverProgress;
  final VoidCallback? onChangeCover;
  final VoidCallback? onViewCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactOverlay = theme.brightness == Brightness.light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      leading: _ToolbarColor(
        scrollOffset: scrollOffset,
        builder: (color) => isRootProfile
            ? IconButton(
                tooltip: menuTooltip,
                icon: Icon(AppIcons.menu, color: color),
                onPressed: onMenuTap,
              )
            : BackButton(color: color),
      ),
      pinned: true,
      stretch: true,
      clipBehavior: Clip.hardEdge,
      expandedHeight: ProfileHeaderGeometry.coverHeightForWidth(screenWidth),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle:
          (usesCompactSystemOverlay
                  ? compactOverlay
                  : SystemUiOverlayStyle.light)
              .copyWith(statusBarColor: Colors.transparent),
      titleSpacing: isRootProfile ? AppSpacing.md : 0,
      title: ValueListenableBuilder<double>(
        valueListenable: scrollOffset,
        builder: (context, offset, _) {
          final opacity = ProfileHeaderGeometry.compactIdentityOpacity(
            offset,
            screenWidth,
          );
          return IgnorePointer(
            ignoring: opacity == 0,
            child: Opacity(
              key: const ValueKey('profile-compact-identity'),
              opacity: opacity,
              child: Row(
                children: [
                  ProfileAvatar(profile: profile, radius: 12, iconSize: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: EmojiSafeText(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.compactAppBarTitle(theme.textTheme),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        _ToolbarColor(
          scrollOffset: scrollOffset,
          builder: (color) => IconButton(
            tooltip: shareTooltip,
            constraints: const BoxConstraints.tightFor(
              width: AppSizes.minTapTarget,
              height: AppSizes.minTapTarget,
            ),
            onPressed: onShare,
            icon: Icon(AppIcons.share, color: color),
          ),
        ),
        if (isOwner)
          _ToolbarColor(
            scrollOffset: scrollOffset,
            builder: (color) => IconButton(
              tooltip: settingsTooltip,
              constraints: const BoxConstraints.tightFor(
                width: AppSizes.minTapTarget,
                height: AppSizes.minTapTarget,
              ),
              onPressed: onSettings,
              icon: Icon(AppIcons.settings, color: color),
            ),
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: _CoverSpace(
        profile: profile,
        scrollOffset: scrollOffset,
        screenWidth: screenWidth,
        isOwner: isOwner,
        progress: coverProgress,
        changeTooltip: changeCoverTooltip,
        onChange: onChangeCover,
        onView: onViewCover,
      ),
    );
  }
}

class _CoverSpace extends StatelessWidget {
  const _CoverSpace({
    required this.profile,
    required this.scrollOffset,
    required this.screenWidth,
    required this.isOwner,
    required this.progress,
    required this.changeTooltip,
    required this.onChange,
    required this.onView,
  });

  final PublicProfile profile;
  final ValueListenable<double> scrollOffset;
  final double screenWidth;
  final bool isOwner;
  final int? progress;
  final String changeTooltip;
  final VoidCallback? onChange;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: scrollOffset,
    builder: (context, offset, _) {
      final compactOpacity = ProfileHeaderGeometry.compactIdentityOpacity(
        offset,
        screenWidth,
      );
      final stretchScale = ProfileHeaderGeometry.stretchScale(
        offset,
        screenWidth,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            key: const ValueKey('profile-cover'),
            scale: stretchScale,
            child: profile.coverPhoto == null
                ? const _FallbackCover()
                : CachedNetworkImage(
                    imageUrl: profile.coverPhoto!,
                    fit: BoxFit.cover,
                  ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000)],
                stops: [0, .58],
              ),
            ),
          ),
          // Transparent tap overlay — lets the SliverAppBar handle scroll
          // while still firing the lightbox on a clean tap.
          if (onView != null && progress == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onView,
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height:
                MediaQuery.paddingOf(context).top +
                ProfileHeaderGeometry.collapsedHeight,
            child: ColoredBox(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: compactOpacity),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 18,
            child: IgnorePointer(
              child: Opacity(
                opacity: 1 - compactOpacity,
                child: DecoratedBox(
                  key: const ValueKey('profile-cover-curved-sheet'),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xl + 4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (progress != null)
            Positioned.fill(
              child: ColoredBox(
                key: const ValueKey('profile-cover-upload-progress'),
                color: const Color(0x88000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$progress%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (isOwner && progress == null && compactOpacity < .5)
            Positioned(
              right: AppSpacing.xs,
              // Keep the 34px visual above the 18px curved content sheet.
              // IconButton adds 7px of padding around that visual.
              bottom: AppSpacing.sm + AppSpacing.xs,
              child: IconButton(
                key: const ValueKey('profile-change-cover-button'),
                tooltip: changeTooltip,
                onPressed: onChange,
                constraints: const BoxConstraints.tightFor(
                  width: AppSizes.minTapTarget,
                  height: AppSizes.minTapTarget,
                ),
                padding: EdgeInsets.zero,
                icon: Material(
                  key: const ValueKey('profile-change-cover-visual'),
                  color: Colors.black.withValues(alpha: .48),
                  elevation: 1,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .28),
                    ),
                  ),
                  child: const SizedBox.square(
                    dimension: 34,
                    child: Icon(
                      AppIcons.camera,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover();

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: const ValueKey('profile-fallback-cover'),
      imageUrl: kDefaultCoverPhoto,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const _FallbackCoverGradient(
        key: ValueKey('profile-fallback-cover-gradient'),
      ),
    );
  }
}

class _FallbackCoverGradient extends StatelessWidget {
  const _FallbackCoverGradient({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
      ),
    );
  }
}

class _ToolbarColor extends StatelessWidget {
  const _ToolbarColor({required this.scrollOffset, required this.builder});

  final ValueListenable<double> scrollOffset;
  final Widget Function(Color color) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: scrollOffset,
    builder: (context, offset, _) => builder(
      Color.lerp(
        Colors.white,
        Theme.of(context).colorScheme.onSurface,
        ProfileHeaderGeometry.compactIdentityOpacity(
          offset,
          MediaQuery.sizeOf(context).width,
        ),
      )!,
    ),
  );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.profile,
    required this.radius,
    required this.iconSize,
    super.key,
  });

  final PublicProfile profile;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) => UserAvatar(
    key: ValueKey('profile-avatar-$radius'),
    name: profile.name,
    gender: profile.gender,
    imageUrl: profile.image,
    size: radius * 2,
    fontSize: iconSize,
    borderWidth: 0,
    boxShadow: const [],
  );
}
