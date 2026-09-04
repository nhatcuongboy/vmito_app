import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/match_elapsed_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';

/// Court number, name, elapsed time and status — the card's top row.
///
/// Tinted per status, like the `CardHeader` background in
/// `vmito-fe/src/components/session/CourtCard.tsx`.
class HostCourtCardHeader extends StatelessWidget {
  const HostCourtCardHeader({required this.court, super.key});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final startTime = court.currentMatch?.startTime;

    final (
      headerBg,
      numberBg,
      titleColor,
      statusLabel,
      badgeBg,
      badgeTextColor,
      badgeBorderColor,
    ) = switch (court.status) {
      CourtStatus.ready => (
        const Color(0xFFFEFCE8), // yellow.50
        const Color(0xFFEAB308), // yellow.500
        const Color(0xFF854D0E), // yellow.800
        l10n.courtStatusReady,
        const Color(0xFFFACC15), // yellow.400
        const Color(0xFF713F12), // yellow.900
        Colors.transparent,
      ),
      CourtStatus.inUse => (
        const Color(0xFFF0FDF4), // green.50
        const Color(0xFF22C55E), // green.500
        const Color(0xFF15803D), // green.700
        l10n.courtStatusPlaying,
        const Color(0xFF22C55E), // green.500
        Colors.white,
        Colors.transparent,
      ),
      CourtStatus.empty => (
        const Color(0xFFF9FAFB), // gray.50
        const Color(0xFF6B7280), // gray.500
        const Color(0xFF374151), // gray.700
        l10n.courtStatusEmpty,
        const Color(0xFFF3F4F6), // gray.100
        const Color(0xFF374151), // gray.700
        const Color(0xFFE5E7EB), // gray.200
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Row(
        children: [
          Container(
            key: ValueKey('host-court-number-${court.id}'),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: numberBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${court.courtNumber}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.courtName(court),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Only a running match has a clock worth showing.
          if (court.status == CourtStatus.inUse && startTime != null) ...[
            MatchElapsedBadge(startTime: startTime),
            const SizedBox(width: AppSpacing.xs),
          ],
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: badgeBorderColor),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
