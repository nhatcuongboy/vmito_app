import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// The "which session, which venue" card shown in the court-call dialog — a
/// mobile-only addition (the web modal has no equivalent) so a player called
/// while browsing elsewhere in the app can identify the game without
/// already knowing which session this is.
class CourtCallInfoCard extends StatelessWidget {
  const CourtCallInfoCard({
    this.sessionName,
    this.venueAddress,
    this.hostName,
    super.key,
  });

  final String? sessionName;
  final String? venueAddress;
  final String? hostName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lines = [
      if (sessionName != null) (AppIcons.sessions, sessionName!),
      if (venueAddress != null) (AppIcons.location, venueAddress!),
      if (hostName != null) (AppIcons.user, hostName!),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, line) in lines.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.xs),
            _InfoLine(icon: line.$1, text: line.$2),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
