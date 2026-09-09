import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_detail_hero.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

@Preview(
  name: 'Session detail loading · Light',
  group: 'Sessions',
  size: Size(390, 844),
)
Widget sessionDetailSkeletonLightPreview() => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(body: SessionDetailSkeleton()),
);

@Preview(
  name: 'Session detail loading · Dark',
  group: 'Sessions',
  size: Size(390, 844),
)
Widget sessionDetailSkeletonDarkPreview() => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(body: SessionDetailSkeleton()),
);

/// Polished loading placeholder for the initial session-detail request.
///
/// Static surfaces preserve the page structure while a single shimmer pass
/// animates only the content placeholders. This keeps the hierarchy readable
/// in both themes and avoids making the whole page flash as one flat block.
class SessionDetailSkeleton extends StatelessWidget {
  const SessionDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final highlight = Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: 0.08),
      palette.muted,
    );

    return Semantics(
      container: true,
      label: AppLocalizations.of(context).commonLoading,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _SkeletonBackdrop(),
          Shimmer.fromColors(
            period: const Duration(milliseconds: 1450),
            baseColor: palette.muted,
            highlightColor: highlight,
            child: const _SkeletonForeground(),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBackdrop extends StatelessWidget {
  const _SkeletonBackdrop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            SizedBox(
              key: const Key('session-detail-skeleton-hero'),
              height: SessionDetailHero.heroHeight,
              child: DecoratedBox(
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      width: 180,
                      height: 180,
                      top: -72,
                      right: -34,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.07,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      width: 120,
                      height: 120,
                      bottom: -42,
                      left: -28,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.035,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: ColoredBox(color: theme.colorScheme.surface)),
          ],
        ),
        Positioned(
          top: SessionDetailHero.heroHeight - AppSpacing.md,
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl + 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonForeground extends StatelessWidget {
  const _SkeletonForeground();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const Key('session-detail-skeleton-scroll'),
    physics: const NeverScrollableScrollPhysics(),
    child: Column(
      children: [
        const SizedBox(
          height: SessionDetailHero.heroHeight,
          child: _HeroContentPlaceholder(),
        ),
        Transform.translate(
          offset: const Offset(0, -16),
          child: const Padding(
            key: Key('session-detail-skeleton-content'),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: _ContentPlaceholder(),
          ),
        ),
      ],
    ),
  );
}

class _HeroContentPlaceholder extends StatelessWidget {
  const _HeroContentPlaceholder();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          top: topInset + AppSpacing.sm,
          left: AppSpacing.md,
          child: const _SkeletonBox(
            key: Key('session-detail-skeleton-back'),
            width: 40,
            height: 40,
            radius: 20,
          ),
        ),
        Positioned(
          top: topInset + AppSpacing.sm,
          right: AppSpacing.md,
          child: const Row(
            children: [
              _SkeletonBox(width: 40, height: 40, radius: 20),
              SizedBox(width: AppSpacing.xs),
              _SkeletonBox(width: 40, height: 40, radius: 20),
            ],
          ),
        ),
        const Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.lg,
          child: _SkeletonBox(width: 104, height: 28),
        ),
        const Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.lg,
          child: _SkeletonBox(width: 78, height: 28),
        ),
      ],
    );
  }
}

class _ContentPlaceholder extends StatelessWidget {
  const _ContentPlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SkeletonBox(width: 246, height: 22, radius: 7),
      SizedBox(height: AppSpacing.xs),
      _SkeletonBox(width: 148, height: 22, radius: 7),
      SizedBox(height: AppSpacing.md),
      _MetadataPlaceholder(),
      SizedBox(height: AppSpacing.md),
      _LocationPlaceholder(),
      SizedBox(height: AppSpacing.md),
      _SectionDivider(),
      SizedBox(height: AppSpacing.md),
      _HostPlaceholder(),
      SizedBox(height: AppSpacing.md),
      _SectionDivider(),
      SizedBox(height: AppSpacing.md),
      _ParticipantsPlaceholder(),
      SizedBox(height: AppSpacing.lg),
      _FactGridPlaceholder(),
      SizedBox(height: AppSpacing.lg),
      _LevelPlaceholder(),
    ],
  );
}

class _MetadataPlaceholder extends StatelessWidget {
  const _MetadataPlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      _InfoLine(iconSize: 20, width: 214, trailingWidth: 54),
      SizedBox(height: AppSpacing.sm + 2),
      _InfoLine(iconSize: 18, width: 172),
    ],
  );
}

class _LocationPlaceholder extends StatelessWidget {
  const _LocationPlaceholder();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SkeletonBox(width: 34, height: 34, radius: 10),
      SizedBox(width: AppSpacing.sm + 4),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: 196, height: 15, radius: 6),
            SizedBox(height: AppSpacing.xs),
            _SkeletonBox(width: 236, height: 12, radius: 6),
          ],
        ),
      ),
      _SkeletonBox(width: 32, height: 32, radius: 16),
    ],
  );
}

class _HostPlaceholder extends StatelessWidget {
  const _HostPlaceholder();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          _SkeletonBox(
            key: Key('session-detail-skeleton-host-avatar'),
            width: 48,
            height: 48,
            radius: 24,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: _SkeletonBox(width: 16, height: 16, radius: 8),
          ),
        ],
      ),
      SizedBox(width: AppSpacing.sm + 4),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: 116, height: 15, radius: 6),
            SizedBox(height: AppSpacing.xs),
            _SkeletonBox(width: 154, height: 12, radius: 6),
          ],
        ),
      ),
      _SkeletonBox(width: 34, height: 34, radius: 12),
      SizedBox(width: AppSpacing.xs),
      _SkeletonBox(width: 34, height: 34, radius: 12),
    ],
  );
}

class _ParticipantsPlaceholder extends StatelessWidget {
  const _ParticipantsPlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _SkeletonBox(width: 28, height: 28, radius: 9),
          SizedBox(width: AppSpacing.sm),
          _SkeletonBox(width: 174, height: 17, radius: 7),
          Spacer(),
          _SkeletonBox(width: 34, height: 14, radius: 6),
        ],
      ),
      SizedBox(height: AppSpacing.md),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _AvatarPlaceholder(showBadge: true, nameWidth: 34),
          _AvatarPlaceholder(showBadge: true, nameWidth: 42),
          _AvatarPlaceholder(showBadge: false, nameWidth: 38),
          _AvatarPlaceholder(showBadge: false, nameWidth: 30),
          _AvatarPlaceholder(showBadge: false, nameWidth: 40),
        ],
      ),
    ],
  );
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({
    required this.showBadge,
    required this.nameWidth,
  });

  final bool showBadge;
  final double nameWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const _SkeletonBox(width: 44, height: 44, radius: 22),
            if (showBadge)
              const Positioned(
                top: -4,
                right: -5,
                child: _SkeletonBox(width: 22, height: 13, radius: 7),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _SkeletonBox(width: nameWidth, height: 9, radius: 5),
      ],
    ),
  );
}

class _FactGridPlaceholder extends StatelessWidget {
  const _FactGridPlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Row(
        children: [
          Expanded(child: _FactCard(lineWidth: 86)),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: _FactCard(lineWidth: 98)),
        ],
      ),
      SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(child: _FactCard(lineWidth: 106)),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: _FactCard(lineWidth: 78)),
        ],
      ),
    ],
  );
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.lineWidth});

  final double lineWidth;

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Row(
      children: [
        const _SkeletonBox(width: 28, height: 28, radius: 9),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: lineWidth, height: 11, radius: 5),
              const SizedBox(height: AppSpacing.xs),
              const _SkeletonBox(width: 48, height: 9, radius: 5),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LevelPlaceholder extends StatelessWidget {
  const _LevelPlaceholder();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _SkeletonBox(width: 28, height: 28, radius: 9),
      SizedBox(width: AppSpacing.sm),
      _SkeletonBox(width: 112, height: 14, radius: 6),
      Spacer(),
      _SkeletonBox(width: 74, height: 28),
    ],
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.iconSize,
    required this.width,
    this.trailingWidth,
  });

  final double iconSize;
  final double width;
  final double? trailingWidth;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _SkeletonBox(width: iconSize, height: iconSize, radius: 7),
      const SizedBox(width: AppSpacing.sm + 4),
      Flexible(
        child: Align(
          alignment: Alignment.centerLeft,
          child: _SkeletonBox(width: width, height: 13, radius: 6),
        ),
      ),
      if (trailingWidth case final trailingWidth?) ...[
        const Spacer(),
        _SkeletonBox(width: trailingWidth, height: 22),
      ],
    ],
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const _SkeletonBox(
    width: double.infinity,
    height: 1,
    radius: 0,
  );
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = AppRadius.pill,
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
