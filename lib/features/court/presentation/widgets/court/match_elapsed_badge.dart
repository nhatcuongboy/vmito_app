import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/application/match_elapsed_provider.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// How long the current match has been running.
///
/// **This is the only widget that watches the ticker.** Watching it from the
/// court card would rebuild the whole board — court painter included — once a
/// minute, on every court at once.
class MatchElapsedBadge extends ConsumerWidget {
  const MatchElapsedBadge({required this.startTime, super.key});

  final DateTime startTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final minutes = ref.watch(matchElapsedProvider(startTime)).asData?.value;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: palette.muted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.clock,
            size: 12,
            color: palette.mutedForeground,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            // Null only for the frame before the stream's first synchronous
            // value lands; "0p" would be a lie for a match that may be an hour
            // old, so say nothing until it does.
            minutes == null
                ? l10n.courtElapsedJustStarted
                : l10n.courtElapsedMinutes(minutes),
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
