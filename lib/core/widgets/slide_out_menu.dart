import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
import 'package:vmito_app/core/widgets/sign_out_confirmation.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Left-hand navigation drawer for discovery and account management.
class SlideOutMenu extends ConsumerWidget {
  const SlideOutMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = ref.watch(
      authControllerProvider.select(
        (state) => state.status == AuthStatus.authenticated,
      ),
    );
    final localeCode = ref.watch(localeControllerProvider).languageCode;
    final uri = GoRouterState.of(context).uri;
    final location = uri.path;
    final selectedDiscoveryTab =
        uri.queryParameters[AppRoutes.homeDiscoveryTabQuery];

    bool isActive(String path) =>
        location == path || location.startsWith('$path/');
    bool isDiscoveryActive(String tab) =>
        location == AppRoutes.home && selectedDiscoveryTab == tab;
    void closeDrawer() => Navigator.of(context).pop();
    void goTo(String route) {
      closeDrawer();
      context.go(route);
    }

    void pushTo(String route) {
      closeDrawer();
      unawaited(context.push(route));
    }

    final canViewHostFinance =
        (user?.isHost ?? false) || (user?.isAdmin ?? false);

    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (isAuthenticated && user != null)
                    _ProfileHeader(
                      user: user,
                      roleLabel: _roleLabel(l10n, user.role),
                      onTap: () => goTo(AppRoutes.profile),
                    ),
                  _MenuSection(
                    title: l10n.menuExplore,
                    children: [
                      _MenuItem(
                        icon: AppIcons.sessions,
                        label: l10n.homeDiscoverySessions,
                        isActive:
                            isDiscoveryActive('sessions') ||
                            (location == AppRoutes.home &&
                                selectedDiscoveryTab == null),
                        onTap: () => goTo(
                          AppRoutes.homeForDiscoveryTab('sessions'),
                        ),
                      ),
                      _MenuItem(
                        icon: AppIcons.location,
                        label: l10n.homeDiscoveryVenues,
                        isActive:
                            isDiscoveryActive('venues') ||
                            isActive(AppRoutes.venues),
                        onTap: () => goTo(
                          AppRoutes.homeForDiscoveryTab('venues'),
                        ),
                      ),
                      _MenuItem(
                        icon: AppIcons.clubs,
                        label: l10n.homeDiscoveryClubs,
                        isActive:
                            isDiscoveryActive('clubs') ||
                            isActive(AppRoutes.clubs),
                        onTap: () => goTo(
                          AppRoutes.homeForDiscoveryTab('clubs'),
                        ),
                      ),
                      _MenuItem(
                        icon: AppIcons.trophy,
                        label: l10n.homeDiscoveryTournaments,
                        isActive:
                            isDiscoveryActive('tournaments') ||
                            isActive(AppRoutes.tournaments),
                        onTap: () => goTo(
                          AppRoutes.homeForDiscoveryTab('tournaments'),
                        ),
                      ),
                      _MenuItem(
                        icon: AppIcons.award,
                        label: l10n.navLeaderboard,
                        isActive: isActive(AppRoutes.leaderboard),
                        onTap: () => pushTo(AppRoutes.leaderboard),
                      ),
                    ],
                  ),
                  if (isAuthenticated && user != null) ...[
                    const _MenuDivider(),
                    _MenuSection(
                      title: l10n.menuManage,
                      children: [
                        _MenuItem(
                          icon: AppIcons.sessions,
                          label: l10n.navSessions,
                          isActive: isActive(AppRoutes.browseSessions),
                          onTap: () => goTo(AppRoutes.browseSessions),
                        ),
                        _MenuItem(
                          icon: AppIcons.userPlus,
                          label: l10n.menuGroups,
                          isActive: isActive(AppRoutes.manageClubs),
                          onTap: () => goTo(AppRoutes.manageClubs),
                        ),
                        if (canViewHostFinance)
                          _MenuItem(
                            icon: AppIcons.billing,
                            label: l10n.transactionDashboardTitle,
                            isActive: isActive(AppRoutes.transactions),
                            onTap: () => pushTo(AppRoutes.transactions),
                          ),
                        _MenuItem(
                          icon: AppIcons.favorite,
                          label: l10n.navFavorites,
                          isActive: isActive(AppRoutes.favorites),
                          onTap: () => goTo(AppRoutes.favorites),
                        ),
                      ],
                    ),
                    const _MenuDivider(),
                    _MenuSection(
                      children: [
                        _MenuItem(
                          icon: AppIcons.settings,
                          label: l10n.settingsTitle,
                          isActive: isActive(AppRoutes.settings),
                          onTap: () => pushTo(AppRoutes.settings),
                        ),
                        _MenuItem(
                          icon: AppIcons.language,
                          label: l10n.profileLanguage,
                          trailing: _languageLabel(l10n, localeCode),
                          onTap: () {
                            closeDrawer();
                            unawaited(showLanguageSelector(context));
                          },
                        ),
                        _MenuItem(
                          icon: AppIcons.help,
                          label: l10n.menuHelpFeedback,
                        ),
                        _MenuItem(
                          icon: AppIcons.logout,
                          label: l10n.authSignOut,
                          destructive: true,
                          onTap: () => unawaited(
                            showSignOutConfirmation(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
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
                ],
              ),
            ),
            const _MenuDivider(),
            _MenuFooter(appName: l10n.appName),
          ],
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
    UserRole.host => l10n.menuRoleHost,
    UserRole.admin => l10n.menuRoleAdmin,
    UserRole.referee => l10n.menuRoleReferee,
    UserRole.player || UserRole.guest => l10n.menuRolePlayer,
  };

  String _languageLabel(AppLocalizations l10n, String code) => switch (code) {
    'en' => l10n.languageEnglish,
    'zh' => l10n.languageChinese,
    _ => l10n.languageVietnamese,
  };
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.roleLabel,
    required this.onTap,
  });

  final User user;
  final String roleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = user.displayName.trim()[0].toUpperCase();
    final hasImage = user.image?.trim().isNotEmpty ?? false;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              foregroundImage: hasImage ? NetworkImage(user.image!) : null,
              child: Text(initials, style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    roleLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.extension<AppPalette>()!.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.chevronRight),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(
                  context,
                ).extension<AppPalette>()!.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ...children,
      ],
    ),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.trailing,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final String? trailing;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final color = destructive
        ? theme.colorScheme.error
        : isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return Material(
      color: isActive
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minTileHeight: 56,
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: trailing == null
            ? null
            : Text(
                trailing!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: palette.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).extension<AppPalette>()!.border,
  );
}

class _MenuFooter extends StatelessWidget {
  const _MenuFooter({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.asset(
              'assets/icons/app-logo-96.png',
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) => Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: appName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: l10n.menuFooterVersion(
                        snapshot.data?.version ?? '—',
                        DateTime.now().year,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview the signed-out menu without depending on native auth services.
@Preview(name: 'Slide-out menu', group: 'Navigation', size: Size(360, 760))
Widget slideOutMenuPreview() {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const SlideOutMenu(),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      locale: const Locale('vi'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}
