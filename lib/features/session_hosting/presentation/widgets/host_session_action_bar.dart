import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Sticky bar pinned above the bottom nav — starts a prepared session.
///
/// Ending one lives in the Overview tab and the app bar's More menu instead:
/// unlike starting, it is not the single next thing a host does, so it does
/// not deserve a permanent slot above the nav bar. Renders nothing once the
/// session is running, finished, or cancelled.
class HostSessionActionBar extends ConsumerWidget {
  const HostSessionActionBar({required this.session, super.key});

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
      _ => null,
    };
    if (action == null) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: SizedBox(width: double.infinity, child: action),
        ),
      ),
    );
  }
}
