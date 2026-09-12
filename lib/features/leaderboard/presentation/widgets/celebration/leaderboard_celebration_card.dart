import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/medal_avatar.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/rank_visuals.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/tier_badge.dart';
import 'package:vmito_app/features/social/application/achievement_share_service.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _countUpDuration = Duration(milliseconds: 900);

class LeaderboardCelebrationCard extends ConsumerStatefulWidget {
  const LeaderboardCelebrationCard({required this.entry, super.key});

  final LeaderboardEntry entry;

  @override
  ConsumerState<LeaderboardCelebrationCard> createState() =>
      _LeaderboardCelebrationCardState();
}

class _LeaderboardCelebrationCardState
    extends ConsumerState<LeaderboardCelebrationCard> {
  final GlobalKey _captureKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = theme.extension<AppPalette>()!;
    final entry = widget.entry;
    final medal = medalVisualsFor(theme.brightness, entry.rank);
    final name = entry.user.name?.trim().isNotEmpty ?? false
        ? entry.user.name!.trim()
        : '—';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Material(
          key: const ValueKey('leaderboard-celebration-card'),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          clipBehavior: Clip.antiAlias,
          child: RepaintBoundary(
            key: _captureKey,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [medal.glow, theme.colorScheme.surface],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.crown, size: 28, color: medal.solid),
                    const SizedBox(height: AppSpacing.sm),
                    MedalAvatar(
                      name: name,
                      imageUrl: entry.user.image,
                      rank: entry.rank,
                      radius: 36,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.leaderboardCelebrationTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    EmojiSafeText(
                      l10n.leaderboardCelebrationRank(entry.rank),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PointsCountUp(points: entry.points),
                    const SizedBox(height: AppSpacing.sm),
                    TierBadge(tier: entry.tier),
                    const SizedBox(height: AppSpacing.lg),
                    _Actions(
                      sharing: _sharing,
                      onShare: _share,
                      onDismiss: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _captureKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final bytes = await ref
          .read(achievementCaptureServiceProvider)
          .capture(boundary);
      if (bytes == null || !mounted) return;
      final box = context.findRenderObject();
      await ref
          .read(achievementShareServiceProvider)
          .sharePng(
            bytes,
            fileName: 'vmito-rank-${widget.entry.rank}.png',
            origin: box is RenderBox
                ? box.localToGlobal(Offset.zero) & box.size
                : null,
          );
    } on Object {
      // Sharing is a bonus here; never bury the congratulations under an error.
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

class _PointsCountUp extends StatelessWidget {
  const _PointsCountUp({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: points),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _countUpDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        l10n.leaderboardCelebrationPoints(value),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.sharing,
    required this.onShare,
    required this.onDismiss,
  });

  final bool sharing;
  final Future<void> Function() onShare;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('leaderboard-celebration-share'),
            onPressed: sharing ? null : onShare,
            icon: const Icon(AppIcons.share, size: 16),
            label: Text(l10n.leaderboardCelebrationShare),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton(
            key: const ValueKey('leaderboard-celebration-dismiss'),
            onPressed: onDismiss,
            child: Text(l10n.leaderboardCelebrationDismiss),
          ),
        ),
      ],
    );
  }
}
