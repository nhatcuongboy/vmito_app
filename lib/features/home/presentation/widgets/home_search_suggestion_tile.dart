import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/utils/search_text.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Shared with the skeleton row so loading and loaded rows line up.
const double homeSearchThumbnailSize = 48;

/// One entity row on the search screen: thumbnail, title with the typed
/// keyword highlighted, and a single line of the details that tell two
/// similar names apart (when, where, how big).
class HomeSearchSuggestionTile extends StatelessWidget {
  const HomeSearchSuggestionTile({
    required this.suggestion,
    required this.onTap,
    this.query = '',
    super.key,
  });

  final DiscoverySuggestion suggestion;
  final VoidCallback onTap;
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final range = searchMatchRange(suggestion.title, query);
    final details = _details(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _Thumbnail(suggestion: suggestion),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    range == null
                        ? TextSpan(text: suggestion.title)
                        : TextSpan(
                            children: [
                              TextSpan(
                                text: suggestion.title.substring(
                                  0,
                                  range.start,
                                ),
                              ),
                              TextSpan(
                                text: suggestion.title.substring(
                                  range.start,
                                  range.end,
                                ),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: suggestion.title.substring(range.end),
                              ),
                            ],
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      details.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _details(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final start = suggestion.startsAt;
    final end = suggestion.endsAt;
    final lead = switch (suggestion.tab) {
      HomeDiscoveryTab.sessions when start != null => Dates.dayWithRange(
        start,
        end,
        locale: locale,
        todayLabel: l10n.dateToday,
        tomorrowLabel: l10n.dateTomorrow,
        yesterdayLabel: l10n.dateYesterday,
      ),
      HomeDiscoveryTab.tournaments when start != null => Dates.shortDateRange(
        start,
        end ?? start,
        locale: locale,
      ),
      HomeDiscoveryTab.clubs => switch (suggestion.memberCount) {
        final int count => l10n.clubMembersCount(count),
        null => null,
      },
      _ => null,
    };
    // Session and venue names often embed their place ("Sân Đại Phát" at
    // "Đại Phát"); repeating it on the detail line is noise.
    final place = suggestion.subtitle?.trim();
    final showPlace =
        place != null &&
        place.isNotEmpty &&
        !containsSearchText(suggestion.title, place);
    return [?lead, if (showPlace) place];
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.suggestion});

  final DiscoverySuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final imageUrl = suggestion.imageUrl;
    // Club images are logos, which read as avatars; everything else is a
    // photo of a place or an event.
    final isClub = suggestion.tab == HomeDiscoveryTab.clubs;
    final fallback = _ThumbnailFallback(tab: suggestion.tab);
    final child = imageUrl == null || imageUrl.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          );
    return SizedBox.square(
      dimension: homeSearchThumbnailSize,
      child: isClub
          ? ClipOval(child: child)
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: child,
            ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.tab});

  final HomeDiscoveryTab tab;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ColoredBox(
      color: primary.withValues(alpha: 0.10),
      child: Icon(
        switch (tab) {
          HomeDiscoveryTab.sessions => AppIcons.sessions,
          HomeDiscoveryTab.venues => AppIcons.venue,
          HomeDiscoveryTab.clubs => AppIcons.clubs,
          HomeDiscoveryTab.tournaments => AppIcons.trophy,
        },
        size: 22,
        color: primary,
      ),
    );
  }
}
