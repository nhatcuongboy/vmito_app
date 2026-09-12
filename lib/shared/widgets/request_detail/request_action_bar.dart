import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The sticky reject/approve bar at the bottom of a join-request detail
/// screen. Each call site owns its own confirmation flow (club requires a
/// rejection reason, session does not) — this bar just runs whatever future
/// it's handed and shows a busy state meanwhile.
class RequestActionBar extends StatelessWidget {
  const RequestActionBar({
    required this.onApprove,
    required this.onReject,
    this.busy = false,
    super.key,
  });

  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => unawaited(onReject()),
                child: Text(l10n.hostManageReject),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : () => unawaited(onApprove()),
                child: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.hostManageApprove),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
