import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Explains which pairings on this court have already happened too often.
Future<void> showMatchRepeatWarningSheet(
  BuildContext context, {
  required MatchRepeatWarning warning,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MatchRepeatWarningSheet(warning: warning),
  );
}

/// Ports `MatchRepeatWarning.tsx`.
///
/// **Advisory only** — it never blocks confirming a match, and says so.
class MatchRepeatWarningSheet extends StatelessWidget {
  const MatchRepeatWarningSheet({required this.warning, super.key});

  final MatchRepeatWarning warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.warning, color: palette.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.matchRepeatTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.matchRepeatDescription, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.matchRepeatHostNote,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: l10n.matchRepeatTeammatesTitle,
              emptyText: l10n.matchRepeatNoTeammates,
              items: warning.repeatedTeammates,
            ),
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: l10n.matchRepeatOpponentsTitle,
              emptyText: l10n.matchRepeatNoOpponents,
              items: warning.repeatedOpponents,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(MaterialLocalizations.of(context).closeButtonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyText,
    required this.items,
  });

  final String title;
  final String emptyText;
  final List<RepeatWarningItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (items.isEmpty)
          Text(
            emptyText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.mutedForeground,
            ),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        _name(context, item.players.$1),
                        _name(context, item.players.$2),
                      ].join(' — '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: palette.warning.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      l10n.matchRepeatMatchCount(item.totalCount),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  /// The player's name, or their shirt number when they joined without one.
  String _name(BuildContext context, RepeatWarningPlayer player) {
    final name = player.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final number = player.playerNumber;
    final l10n = AppLocalizations.of(context);
    return number == null ? l10n.playerFallback : l10n.playerNumbered(number);
  }
}
