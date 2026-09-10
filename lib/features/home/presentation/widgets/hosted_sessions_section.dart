import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card_skeleton.dart';
import 'package:vmito_app/features/session_hosting/application/hosted_sessions_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The sessions this user hosts.
///
/// Shrink-wrapped inside the home `ListView` rather than scrolling itself:
/// two scrollables on one screen make the inner one nearly impossible to
/// reach with a thumb.
class HostedSessionsSection extends ConsumerWidget {
  const HostedSessionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final sessions = ref.watch(hostedSessionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.homeHostedSessions, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        sessions.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => Semantics(
            container: true,
            label: l10n.commonLoading,
            child: const Column(
              children: [
                SessionCardSkeleton(showHostInfo: false),
                SizedBox(height: AppSpacing.md),
                SessionCardSkeleton(showHostInfo: false),
              ],
            ),
          ),
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(hostedSessionsProvider),
          ),
          data: (page) => page.items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                  ),
                  child: Text(
                    l10n.homeHostedEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final session in page.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: SessionCard(
                          session: session,
                          hideHostInfo: true,
                          onTap: () => context.push(
                            AppRoutes.manageSession(session.id),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
