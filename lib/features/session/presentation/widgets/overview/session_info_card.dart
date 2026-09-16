import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_fee_detail_dialog.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_info_row.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_level_badges.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/expandable_text.dart';

/// Session details card: name, host, time, location, capacity, levels, fee,
/// description and notes. Shared by both the host and player overview tabs.
class SessionInfoCard extends StatelessWidget {
  const SessionInfoCard({
    required this.session,
    required this.showNewAddress,
    this.onEdit,
    super.key,
  });
  final Session session;
  final bool showNewAddress;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final capacity = session.capacity;
    final feeConfig = session.feeConfig;
    final feeLabel = feeConfig == null
        ? null
        : sessionPriceLabel(session, locale) ??
              (feeConfig.isSplitEvenly
                  ? l10n.sessionFormFeeSplit
                  : l10n.feeNotSet);
    final showPerSlot =
        feeConfig != null &&
        !feeConfig.isSplitEvenly &&
        ((feeConfig.maleFee ?? 0) > 0 || (feeConfig.femaleFee ?? 0) > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCardHeader(onEdit: onEdit),
            SessionInfoRow(
              icon: AppIcons.sessions,
              alignCenter: true,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      session.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (session.isInternal) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs + 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        l10n.sessionInternalBadge,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? Colors.purple.shade300
                              : Colors.purple.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (session.displayHostName.isNotEmpty)
              SessionInfoRow(
                icon: AppIcons.user,
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                label: session.displayHostName,
              ),
            SessionInfoRow(
              icon: AppIcons.calendar,
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              label: session.displayStartTime == null
                  ? 'Chưa có thời gian'
                  : Dates.dayWithRange(
                      session.displayStartTime!,
                      session.plannedEndTime,
                      locale: locale,
                    ),
            ),
            if (session.hasLocation)
              SessionInfoRow(
                icon: AppIcons.location,
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                label: session.displayPlace(showNewAddress: showNewAddress),
              ),
            const SessionInfoGroupDivider(),
            SessionInfoRow(
              icon: AppIcons.square,
              label: capacity > 0
                  ? '${session.numberOfCourts} sân · '
                        '${session.maxPlayersPerCourt} người/sân · '
                        '${l10n.sessionMaxPlayers(capacity)}'
                  : '${session.numberOfCourts} sân · '
                        '${session.maxPlayersPerCourt} người/sân',
            ),
            if (session.shuttlecock case final brand?
                when brand.trim().isNotEmpty)
              SessionInfoRow(
                icon: AppIcons.tag,
                label: l10n.sessionShuttlecock(brand.trim()),
              ),
            SessionInfoRow(
              icon: AppIcons.badge,
              alignCenter: true,
              topPadding: 8,
              child: SessionLevelBadges(levels: session.requiredLevels),
            ),
            if (feeLabel != null && feeConfig != null) ...[
              const SessionInfoGroupDivider(),
              SessionInfoRow(
                icon: AppIcons.creditCard,
                alignCenter: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: feeLabel,
                              style: TextStyle(
                                color: palette.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (showPerSlot)
                              TextSpan(
                                text: ' ${l10n.sessionPerSlot}',
                                style: TextStyle(
                                  color: palette.mutedForeground,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('host-overview-fee-info'),
                      tooltip: l10n.feeTitle,
                      onPressed: () => unawaited(
                        showSessionFeeDetailDialog(
                          context,
                          feeConfig: feeConfig,
                        ),
                      ),
                      icon: const Icon(AppIcons.info, size: 17),
                      color: theme.colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
            if (session.description?.trim().isNotEmpty ?? false) ...[
              const Divider(height: 24),
              Text(
                l10n.sessionDescriptionTitle,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              ExpandableText(text: session.description!),
            ],
            if (session.notes?.trim().isNotEmpty ?? false) ...[
              const Divider(height: 24),
              Text(
                l10n.sessionOverviewNotesTitle,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 3),
              Text(session.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCardHeader extends StatelessWidget {
  const _InfoCardHeader({this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          AppLocalizations.of(context).sessionOverviewInfoTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      if (onEdit != null) ...[
        const SizedBox(width: AppSpacing.sm),
        TextButton.icon(
          key: const Key('host-overview-edit-session'),
          onPressed: onEdit,
          icon: const Icon(AppIcons.edit, size: 16),
          label: Text(AppLocalizations.of(context).hostManageEditSession),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, AppSizes.minTapTarget),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
        ),
      ],
    ],
  );
}
