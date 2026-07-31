import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/home/presentation/widgets/hosted_sessions_section.dart';
import 'package:vmito_app/features/session/application/hosted_sessions_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The host's landing screen.
///
/// P3 entry point: the sessions this user runs, and the way to create another.
/// A player with no hosted sessions sees the browse call-to-action instead, so
/// the screen is never an empty shell.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vmito'),
        actions: [
          IconButton(
            tooltip: l10n.notificationsTitle,
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(hostedSessionsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              l10n.homeGreeting(user?.displayName ?? ''),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            const HostedSessionsSection(),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.transactions),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n.transactionDashboardTitle),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.browseSessions),
              icon: const Icon(Icons.stadium_outlined),
              label: Text(l10n.homeBrowseSessions),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createSession),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.createSessionTitle),
      ),
    );
  }
}
