import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/notification_header_button.dart';
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
    required this.onMenuTap,
    required this.onShare,
    required this.onSettings,
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
  final VoidCallback onMenuTap;
  final VoidCallback onShare;
  final VoidCallback onSettings;

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
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          builder: (color) => NotificationHeaderButton(color: color),
        ),
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
      ],
      flexibleSpace: _CoverSpace(
        profile: profile,
        scrollOffset: scrollOffset,
        screenWidth: screenWidth,
      ),
    );
  }
}

class _CoverSpace extends StatelessWidget {
  const _CoverSpace({
    required this.profile,
    required this.scrollOffset,
    required this.screenWidth,
  });

  final PublicProfile profile;
  final ValueListenable<double> scrollOffset;
  final double screenWidth;

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
        ],
      );
    },
  );
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('profile-fallback-cover'),
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
  Widget build(BuildContext context) => CircleAvatar(
    key: ValueKey('profile-avatar-$radius'),
    radius: radius,
    backgroundImage: profile.image == null
        ? null
        : CachedNetworkImageProvider(profile.image!),
    child: profile.image == null
        ? Icon(AppIcons.profile, size: iconSize)
        : null,
  );
}
