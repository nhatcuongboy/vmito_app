import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/application/court_selection_controller.dart';
import 'package:vmito_app/features/court/domain/court_seating.dart';
import 'package:vmito_app/features/court/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/ai_toggle_card.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/match_pair_stats.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';

/// Let the server pick the line-up.
///
/// Matchmaking is server-side — this renders `GET /courts/:id/suggested-players`
/// and never computes a pairing (CLAUDE.md non-negotiable #4).
class CourtSelectionAutoTab extends ConsumerWidget {
  const CourtSelectionAutoTab({
    required this.selectionKey,
    required this.court,
    super.key,
  });

  final CourtSelectionKey selectionKey;
  final Court court;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(courtSelectionControllerProvider(selectionKey));
    final controller = ref.read(
      courtSelectionControllerProvider(selectionKey).notifier,
    );

    final suggestion = state.suggestion;
    final error = state.suggestionError;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        AiToggleCard(
          useAi: state.useAi,
          onChanged: (value) => controller.setUseAi(useAi: value),
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.isLoadingSuggestion)
          _Centred(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  state.useAi
                      ? l10n.courtAiAnalyzing
                      : l10n.courtLoadingSuggestions,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
          )
        else if (error != null)
          _Centred(
            child: Column(
              children: [
                Text(
                  // A BadRequest here means "not enough waiting players", which
                  // the backend words better than we could.
                  error is ApiException
                      ? l10n.apiError(error)
                      : l10n.courtErrorSuggestions,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: controller.unawaitedRefreshSuggestion,
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          )
        else if (suggestion != null) ...[
          BadmintonCourtView(
            court: court,
            mode: CourtViewMode.manage,
            matchType: state.matchType,
            // The same mapping the controller submits, so the preview cannot
            // show one arrangement and send another.
            selection: CourtSeating.seatedPreview(
              suggestion.pair1.players,
              suggestion.pair2.players,
              matchType: state.matchType,
              direction: court.direction,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          MatchPairStats(
            seats: [...suggestion.pair1.players, ...suggestion.pair2.players],
            matchType: state.matchType,
          ),
          if (suggestion.aiReason case final reason?) ...[
            const SizedBox(height: AppSpacing.md),
            _ReasonPanel(reason: reason),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _ReasonPanel extends StatelessWidget {
  const _ReasonPanel({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.muted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).courtAiReasoning,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(reason, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Centred extends StatelessWidget {
  const _Centred({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Center(child: child),
  );
}
