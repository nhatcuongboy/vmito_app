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

/// "Gợi ý cho bạn" — the web app's `SessionRecommendations`, mobile variant.
///
/// Renders nothing while loading, on error, or when the backend has nothing
/// to suggest: this is a tail-end upsell, and a spinner or an error card for
/// it would look like the page itself failed.
class SessionRecommendations extends ConsumerWidget {
  const SessionRecommendations({required this.sessionId, super.key});

  final String sessionId;

  static const _cardWidth = 220.0;

  /// Sized for the worst case the rail actually gets: a two-line title plus
  /// both meta lines and a price. A tighter box overflows on long names,
  /// which is most of them.
  static const _cardHeight = 232.0;
  static const _coverHeight = 88.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sessions =
        ref.watch(sessionRecommendationsProvider(sessionId)).value ??
        const <Session>[];
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Column(
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
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => SizedBox(
              width: _cardWidth,
              child: _RecommendationCard(session: sessions[index]),
            ),
          ),
        ),
      ],
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
      color: Colors.black.withValues(alpha: 0.6),
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
