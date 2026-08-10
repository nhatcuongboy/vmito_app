import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
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
    final action = switch (session.status) {
      SessionStatus.preparing => FilledButton.icon(
        key: const ValueKey('start-session'),
        onPressed: controller.startSession,
        icon: const Icon(AppIcons.play),
        label: Text(l10n.hostManageStartSession),
      ),
      SessionStatus.inProgress => OutlinedButton.icon(
        key: const ValueKey('end-session'),
        onPressed: controller.endSession,
        icon: const Icon(AppIcons.stop),
        label: Text(l10n.hostManageEndSession),
      ),
      _ => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              session.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            );
            if (action == null) return title;
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.sm),
                  action,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.md),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}
