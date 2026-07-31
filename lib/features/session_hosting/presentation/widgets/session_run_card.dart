import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SessionRunCard extends ConsumerWidget {
  const SessionRunCard({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      hostSessionManagementControllerProvider(session.id).notifier,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (session.status == SessionStatus.preparing)
              FilledButton.icon(
                key: const ValueKey('start-session'),
                onPressed: controller.startSession,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.hostManageStartSession),
              )
            else if (session.status == SessionStatus.inProgress)
              OutlinedButton.icon(
                key: const ValueKey('end-session'),
                onPressed: controller.endSession,
                icon: const Icon(Icons.stop_rounded),
                label: Text(l10n.hostManageEndSession),
              ),
          ],
        ),
      ),
    );
  }
}
