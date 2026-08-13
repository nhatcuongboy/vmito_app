import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/application/player/session_recommendations_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// "Gợi ý kèo" — the web app's `SessionRecommendations`, mobile variant.
///
/// Renders nothing while loading, on error, or when the backend has nothing
/// to suggest: this is a tail-end upsell, and a spinner or an error card for
/// it would look like the page itself failed.
class SessionRecommendations extends ConsumerWidget {
  const SessionRecommendations({required this.sessionId, super.key});

  final String sessionId;

  /// The web uses roughly 75vw on mobile, capped so a second card remains
  /// visible as a deliberate invitation to swipe.
  static double _cardWidth(double availableWidth) =>
      (availableWidth * .75).clamp(280.0, 320.0);

  static const _cardHeight = 270.0;
  static const _coverHeight = 132.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sessions =
        ref.watch(sessionRecommendationsProvider(sessionId)).value ??
        const <Session>[];
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
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
              height: _cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: sessions.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: _cardWidth(constraints.maxWidth),
                  child: _RecommendationCard(session: sessions[index]),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton.icon(
              onPressed: () => context.go(AppRoutes.home),
              icon: const Icon(AppIcons.arrowForward, size: 18),
              label: Text(l10n.sessionViewAllSessions),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cover = session.galleryImages.firstOrNull;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        // `push`, not `go`: recommendations chain, and a player who taps three
        // of them expects three taps of back to return here.
        onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: SessionRecommendations._coverHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover == null)
                    ColoredBox(
                      color: palette.muted,
                      child: Icon(
                        AppIcons.sessions,
                        color: palette.mutedForeground,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      placeholder: (context, _) =>
                          ColoredBox(color: palette.muted),
                      errorWidget: (context, _, _) =>
                          ColoredBox(color: palette.muted),
                    ),
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: _SuggestionBadge(label: l10n.sessionSuggestedBadge),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (sessionTimeRangeLabel(session, l10n, locale)
                        case final time?)
                      _MetaLine(
                        icon: AppIcons.clock,
                        text: time,
                        color: palette.warning,
                      ),
                    if (session.displayPlace.isNotEmpty)
                      _MetaLine(
                        icon: AppIcons.location,
                        text: session.displayPlace,
                        color: palette.mutedForeground,
                      ),
                    const Spacer(),
                    if (sessionPriceLabel(session, locale) case final price?)
                      Text(
                        price,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}
