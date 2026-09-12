import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard_periods.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_period_controls.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Future<LeaderboardPeriodOption?> showLeaderboardPeriodPicker(
  BuildContext context, {
  required LeaderboardPeriod period,
  required String? periodKey,
}) {
  final options = recentLeaderboardPeriods(period);
  return showModalBottomSheet<LeaderboardPeriodOption>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                l10n.leaderboardPeriodPickerTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final option in options)
              ListTile(
                key: ValueKey('leaderboard-period-option-${option.key}'),
                onTap: () => Navigator.of(context).pop(option),
                trailing: (periodKey ?? options.first.key) == option.key
                    ? Icon(
                        AppIcons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                title: Text(periodOptionLabel(l10n, period, option)),
              ),
          ],
        ),
      );
    },
  );
}
