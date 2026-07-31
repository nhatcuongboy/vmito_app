import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Title, time, place, host and capacity for the detail screen.
class SessionHeader extends StatelessWidget {
  const SessionHeader({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (session.displayStartTime case final time?)
          _InfoRow(
            icon: Icons.schedule_rounded,
            text: Dates.dayAndTime(time, locale: locale),
          ),
        if (session.location case final location? when location.isNotEmpty)
          _InfoRow(icon: Icons.place_outlined, text: location),
        if (session.displayHostName.isNotEmpty)
          _InfoRow(
            icon: Icons.person_outline_rounded,
            text: session.displayHostName,
          ),
        _InfoRow(
          icon: Icons.grid_view_rounded,
          text: session.capacity > 0
              ? l10n.sessionCourtCapacity(
                  session.numberOfCourts,
                  session.capacity,
                )
              : l10n.sessionCourtCount(session.numberOfCourts),
        ),
        if (!session.isJoinable)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              session.isCrawled
                  ? l10n.sessionCrawledReadOnly
                  : l10n.sessionClosed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.mutedForeground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
