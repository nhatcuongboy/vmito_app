import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/host_tournament_more_menu.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/host_tournament_status_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// One row of the host list — ports `TournamentRow` from the web page.
class HostTournamentCard extends StatelessWidget {
  const HostTournamentCard({
    required this.tournament,
    required this.onTap,
    required this.actions,
    this.isDeleting = false,
    this.now,
    super.key,
  });

  final TournamentSummary tournament;
  final VoidCallback onTap;
  final List<HostTournamentCardAction> actions;
  final bool isDeleting;

  /// Overrides the clock for the overdue check; tests only.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final status = HostTournamentDisplayStatus.of(tournament, now: now);
    final venue = tournament.venueName?.trim();
    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: status.linearGradient),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 4, 12),
              child: Row(
                children: [
                  _Thumbnail(tournament: tournament, status: status),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            HostTournamentStatusBadge(status: status),
                            if (!tournament.isPublished)
                              const HostTournamentDraftBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tournament.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: 4,
                          children: [
                            _Meta(
                              icon: AppIcons.calendar,
                              text: Dates.dayRange(
                                _calendarDay(tournament.startDate),
                                _calendarDay(tournament.endDate),
                                locale: Localizations.localeOf(
                                  context,
                                ).languageCode,
                              ),
                            ),
                            if (venue != null && venue.isNotEmpty)
                              _Meta(icon: AppIcons.location, text: venue),
                            _Meta(
                              icon: AppIcons.layers,
                              text: l10n.hostTournamentsCategoryCount(
                                tournament.categoryCount,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  HostTournamentMoreMenu(
                    tournamentId: tournament.id,
                    actions: actions,
                    isDeleting: isDeleting,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tournament dates are stored as UTC midnight; the UTC date part is the
  /// calendar day in every zone, where `toLocal` would slip a day west of UTC.
  static DateTime _calendarDay(DateTime value) {
    final utc = value.toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.tournament, required this.status});

  final TournamentSummary tournament;
  final HostTournamentDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: status.linearGradient),
      child: const Center(
        child: Icon(AppIcons.trophy, color: Colors.white, size: 28),
      ),
    );
    final cover = tournament.coverPhoto;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox.square(
        dimension: 56,
        child: cover == null || cover.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(
                  color: Theme.of(context).extension<AppPalette>()!.muted,
                ),
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.extension<AppPalette>()!.mutedForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
