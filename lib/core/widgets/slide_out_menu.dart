import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Left-hand navigation drawer — the mobile counterpart of the web app's
/// `SlideOutMenu` (`vmito-fe/src/components/ui/SlideOutMenu`).
///
/// Only lists destinations that actually exist on mobile today. The web
/// sidebar's Management/Settings/Admin sections (venues, tournaments,
/// rentals, payment settings, the whole admin console) have no screens here
/// yet, so they're left out rather than wired to placeholders.
class SlideOutMenu extends ConsumerWidget {
  const SlideOutMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final isSignedIn = ref.watch(isSignedInProvider);
    final location = GoRouterState.of(context).uri.path;

    bool isActive(String path) =>
        location == path || location.startsWith('$path/');

    void closeDrawer() => Navigator.of(context).pop();

    return Drawer(
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                l10n.appName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                children: [
                  _MenuItem(
                    icon: AppIcons.home,
                    selectedIcon: AppIcons.home,
                    label: l10n.navHome,
                    isActive: isActive(AppRoutes.home),
                    onTap: () {
                      closeDrawer();
                      context.go(AppRoutes.home);
                    },
                  ),
                  _MenuItem(
                    icon: AppIcons.location,
                    selectedIcon: AppIcons.location,
                    label: 'Sân',
                    isActive: isActive(AppRoutes.venues),
                    onTap: () {
                      closeDrawer();
                      context.go(AppRoutes.venues);
                    },
                  ),
                  _MenuItem(
                    icon: AppIcons.clubs,
                    selectedIcon: AppIcons.clubs,
                    label: 'Câu lạc bộ',
                    isActive: isActive(AppRoutes.clubs),
                    onTap: () {
                      closeDrawer();
                      context.go(AppRoutes.clubs);
                    },
                  ),
                  _MenuItem(
                    icon: AppIcons.sessions,
                    selectedIcon: AppIcons.sessions,
                    label: l10n.navSessions,
                    isActive: isActive(AppRoutes.browseSessions),
                    onTap: () {
                      closeDrawer();
                      context.go(AppRoutes.browseSessions);
                    },
                  ),
                  _MenuItem(
                    icon: AppIcons.feed,
                    selectedIcon: AppIcons.feed,
                    label: l10n.navFeed,
                    isActive: isActive(AppRoutes.feed),
                    onTap: () {
                      closeDrawer();
                      context.go(AppRoutes.feed);
                    },
                  ),
                  _MenuItem(
                    icon: AppIcons.profile,
                    selectedIcon: AppIcons.profile,
                    label: l10n.navProfile,
                    isActive: isActive(AppRoutes.profile),
                    onTap: () {
                      closeDrawer();
                      context.go(AppRoutes.profile);
                    },
                  ),
                  // Notifications and transactions require an account —
                  // hidden rather than shown-then-redirected to sign-in.
                  if (isSignedIn) ...[
                    Divider(height: AppSpacing.lg, color: palette.border),
                    _MenuItem(
                      icon: AppIcons.notifications,
                      selectedIcon: AppIcons.notifications,
                      label: l10n.navNotifications,
                      isActive: isActive(AppRoutes.notifications),
                      onTap: () {
                        closeDrawer();
                        context.go(AppRoutes.notifications);
                      },
                    ),
                    _MenuItem(
                      icon: AppIcons.billing,
                      selectedIcon: AppIcons.billing,
                      label: l10n.transactionDashboardTitle,
                      isActive: isActive(AppRoutes.transactions),
                      onTap: () {
                        closeDrawer();
                        unawaited(context.push(AppRoutes.transactions));
                      },
                    ),
                  ],
                  Divider(height: AppSpacing.lg, color: palette.border),
                  ListTile(
                    leading: const Icon(AppIcons.language),
                    title: Text(l10n.profileLanguage),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    onTap: () {
                      closeDrawer();
                      unawaited(showLanguageSelector(context));
                    },
                  ),
                ],
              ),
            ),
            // Mirrors the web sidebar's `showAuthActions`: only rendered
            // when signed out, never as a sign-out shortcut.
            if (!isSignedIn)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          closeDrawer();
                          unawaited(context.push(AppRoutes.signIn));
                        },
                        child: Text(l10n.authSignIn),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          closeDrawer();
                          unawaited(context.push(AppRoutes.signUp));
                        },
                        child: Text(l10n.authSignUp),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Text(
                l10n.footerCopyright(DateTime.now().year, l10n.appName),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;

    // A ListTile paints its background/ink on the nearest Material ancestor,
    // so the active tint needs its own Material rather than a plain
    // DecoratedBox — otherwise the tap ripple renders invisibly behind it.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isActive
            ? activeColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(
            isActive ? selectedIcon : icon,
            color: isActive ? activeColor : null,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : null,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
