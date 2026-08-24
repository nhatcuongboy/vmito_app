import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';

/// What the host chose to do next, from the preview sheet.
enum PreSelectPreviewAction { cancelPreSelection }

/// Shows the line-up booked for a court's next match.
///
/// Resolves to [PreSelectPreviewAction.cancelPreSelection] when the host clears
/// it, and to null when they just close the sheet.
Future<PreSelectPreviewAction?> showPreSelectPreviewSheet(
  BuildContext context, {
  required Session session,
  required Court court,
}) {
  return showModalBottomSheet<PreSelectPreviewAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PreSelectPreviewSheet(session: session, court: court),
  );
}

/// Ports `PreSelectPreviewModal.tsx`.
///
/// The players are resolved locally against the roster already on screen
/// rather than re-fetched from `GET /courts/:id/pre-select`: a second source
/// could disagree with the board the host is looking at.
class PreSelectPreviewSheet extends StatelessWidget {
  const PreSelectPreviewSheet({
    required this.session,
    required this.court,
    super.key,
  });

  final Session session;
  final Court court;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final players = session.preSelectedPlayersFor(court);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.courtNextMatchPreviewTitle(court.courtNumber),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.courtNextMatchPreviewDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (players.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  l10n.courtNoPreSelectedPlayers,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              BadmintonCourtView(
                // The court itself is mid-match; this preview is about who
                // comes next, so it is drawn from the pre-selection alone.
                court: court.copyWith(
                  status: CourtStatus.ready,
                  currentPlayers: const [],
                  currentMatch: null,
                ),
                preSelectedPlayers: players,
                mode: CourtViewMode.manage,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final player in players)
                    Chip(
                      label: Text(l10n.playerName(player)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (players.isNotEmpty)
              OutlinedButton.icon(
                key: const ValueKey('cancel-pre-selection'),
                onPressed: () => _confirmCancel(context),
                icon: const Icon(AppIcons.delete, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                label: Text(l10n.courtCancelPreSelect),
              ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// Clearing the next line-up is not undoable and the players have already
  /// been told they are up, so it takes a confirmation.
  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.courtConfirmCancelPreSelectTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320),
          child: Text(l10n.courtConfirmCancelPreSelectMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.courtCancelPreSelect),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.pop(context, PreSelectPreviewAction.cancelPreSelection);
  }
}
