import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Cancelled/finished banner shown at the top of a session overview tab.
class SessionStatusBanner extends StatelessWidget {
  const SessionStatusBanner({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    if (session.status != SessionStatus.cancelled &&
        session.status != SessionStatus.finished) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final cancelled = session.status == SessionStatus.cancelled;
    final color = cancelled
        ? Theme.of(context).colorScheme.outline
        : Colors.blue;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(
            cancelled ? AppIcons.cancel : AppIcons.checkCircle,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cancelled
                  ? l10n.sessionOverviewCancelledMessage
                  : l10n.sessionOverviewFinishedMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
