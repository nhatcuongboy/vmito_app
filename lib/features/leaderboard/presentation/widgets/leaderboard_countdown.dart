import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Under a day left the chip turns warning-coloured — the period closing is the
/// one thing on this screen that is time-sensitive.
const _urgentThreshold = Duration(hours: 24);

class LeaderboardCountdown extends StatefulWidget {
  const LeaderboardCountdown({
    required this.endsAt,
    required this.isCurrent,
    super.key,
  });

  final DateTime? endsAt;
  final bool isCurrent;

  @override
  State<LeaderboardCountdown> createState() => _LeaderboardCountdownState();
}

class _LeaderboardCountdownState extends State<LeaderboardCountdown> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant LeaderboardCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt ||
        oldWidget.isCurrent != widget.isCurrent) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    _tick();
    if (widget.endsAt != null && widget.isCurrent) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    }
  }

  void _tick() {
    final end = widget.endsAt;
    final next = end?.difference(DateTime.now());
    if (mounted) setState(() => _remaining = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = theme.extension<AppPalette>()!;
    if (widget.endsAt == null) return const SizedBox.shrink();
    if (!widget.isCurrent) {
      return _Chip(
        color: palette.mutedForeground,
        label: l10n.leaderboardCountdownClosed,
      );
    }
    final remaining = _remaining;
    if (remaining == null) return const SizedBox.shrink();
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final days = safe.inDays;
    final value = days > 0
        ? '${l10n.leaderboardCountdownDays(days)} '
              '${l10n.leaderboardCountdownHours(safe.inHours % 24)}'
        : '${l10n.leaderboardCountdownHours(safe.inHours)} '
              '${l10n.leaderboardCountdownMinutes(safe.inMinutes % 60)}';
    return _Chip(
      color: safe < _urgentThreshold
          ? palette.warning
          : palette.mutedForeground,
      label: l10n.leaderboardCountdownEndsIn,
      value: value,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.label, this.value});

  final Color color;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.clock, size: 13, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    if (value != null)
                      TextSpan(
                        text: ' $value',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
