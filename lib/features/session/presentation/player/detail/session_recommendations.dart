import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/application/player/session_recommendations_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/domain/session_recommendation.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The mobile recommendation rail from the web session-detail page.
class SessionRecommendations extends ConsumerWidget {
  const SessionRecommendations({required this.sessionId, super.key});

  final String sessionId;

  static double _cardWidth(double availableWidth) =>
      (availableWidth * .75).clamp(280.0, 320.0);

  // The metadata and price row need 108 logical pixels below the image at a
  // normal text scale. At 220 the card body only gets 100 pixels, which made
  // the detail page's recommendation cards overflow by 8 pixels vertically.
  static const _cardHeight = 228.0;
  static const _coverHeight = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(sessionRecommendationsProvider(sessionId));
    final page = state.value;

    if (page == null) {
      return state.isLoading
          ? const _RecommendationSkeleton()
          : const SizedBox.shrink();
    }
    if (page.isEmpty) return const SizedBox.shrink();

    final title = page.isFallback
        ? l10n.sessionPopularSessions
        : l10n.sessionRecommendationsTitle;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Semantics(
        container: true,
        label: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: _cardHeight,
                child: ListView.separated(
                  key: const Key('session-recommendations-list'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) => SizedBox(
                    width: _cardWidth(constraints.maxWidth),
                    child: _RecommendationCard(
                      recommendation: page.items[index],
                      showAIBadge: !page.isFallback,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                key: const Key('session-recommendations-view-all'),
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(AppIcons.arrowForward, size: 18),
                label: Text(l10n.sessionViewAllSessions),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  minimumSize: const Size(44, 44),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationSkeleton extends StatelessWidget {
  const _RecommendationSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Container(
      color: theme.colorScheme.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              l10n.sessionRecommendationsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: SessionRecommendations._cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: 3,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, _) => Shimmer.fromColors(
                  baseColor: palette.muted,
                  highlightColor: theme.colorScheme.surface,
                  child: Container(
                    width: SessionRecommendations._cardWidth(
                      constraints.maxWidth,
                    ),
                    decoration: BoxDecoration(
                      color: palette.muted,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.showAIBadge,
  });

  final SessionRecommendation recommendation;
  final bool showAIBadge;

  @override
  Widget build(BuildContext context) {
    final session = recommendation.session;
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cover = session.coverPhoto?.trim().isNotEmpty == true
        ? session.coverPhoto!.trim()
        : Session.defaultCoverPhoto;
    final slots = recommendation.displayAvailableSlots;
    final maxSlots = recommendation.displayMaxSlots;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Semantics(
        button: true,
        label: session.name,
        child: InkWell(
          // Recommendations form a detail chain, so Back returns to the
          // previous session rather than abandoning the detail screen.
          onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: SessionRecommendations._coverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      placeholder: (context, _) =>
                          ColoredBox(color: palette.muted),
                      errorWidget: (context, _, _) => ColoredBox(
                        color: palette.muted,
                        child: Icon(
                          AppIcons.sessions,
                          color: palette.mutedForeground,
                        ),
                      ),
                    ),
                    if (showAIBadge)
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: _SuggestionBadge(
                          label: l10n.sessionSuggestedBadge,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (session.displayPlace.isNotEmpty)
                        _MetaLine(
                          icon: AppIcons.location,
                          text: session.displayPlace,
                          color: theme.colorScheme.primary,
                        ),
                      if (sessionDetailTimeLabel(session, locale)
                          case final time?)
                        _MetaLine(
                          icon: AppIcons.clock,
                          text: time,
                          color: theme.colorScheme.primary,
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _feeLabel(session.feeConfig, l10n, locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (slots != null && maxSlots != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(
                              AppIcons.users,
                              size: 15,
                              color: palette.mutedForeground,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$slots/$maxSlots',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _feeLabel(
    SessionFeeConfig? feeConfig,
    AppLocalizations l10n,
    String locale,
  ) {
    if (feeConfig == null) return l10n.sessionRecommendationFree;
    if (feeConfig.isSplitEvenly) return l10n.sessionRecommendationSplitEvenly;
    return sessionPriceLabel(recommendation.session, locale) ??
        l10n.sessionRecommendationFree;
  }
}

class _SuggestionBadge extends StatelessWidget {
  const _SuggestionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF8B2BE2),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.sparkles, size: 11, color: Colors.white),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
