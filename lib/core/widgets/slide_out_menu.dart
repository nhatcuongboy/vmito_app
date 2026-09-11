import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/core/web/admin_web_destination.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
import 'package:vmito_app/core/widgets/sign_out_confirmation.dart';
import 'package:vmito_app/core/widgets/theme_mode_selector.dart';
import 'package:vmito_app/features/ai/application/ai_assistant_controller.dart';
import 'package:vmito_app/features/ai/presentation/ai_assistant_sheet.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_header_backdrop.dart';
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
    final themeMode = ref.watch(themeModeControllerProvider);
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

    void confirmSignOut() {
      closeDrawer();
      unawaited(showSignOutConfirmation(context, ref));
    }

    final isSignedIn = isAuthenticated && user != null;
    final isAiAssistantEnabled =
        isSignedIn && ref.watch(aiAssistantFeatureEnabledProvider);
    final canViewHostFinance =
        (user?.isHost ?? false) || (user?.isAdmin ?? false);

    void openAiAssistant() {
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final onClosed = ref
          .read(aiAssistantControllerProvider.notifier)
          .stopStreaming;
      closeDrawer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!rootNavigator.mounted) return;
        unawaited(
          showAiAssistantSheet(
            rootNavigator.context,
            routePath: location,
            onClosed: onClosed,
          ),
        );
      });
    }

    // Leaves at least 56dp of the underlying screen visible (Material spec)
    // instead of a fixed 320 that swallows nearly all of a small phone.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = (screenWidth - 56).clamp(200.0, 320.0);

    return Drawer(
      width: drawerWidth,
      child: Stack(
        children: [
          SafeArea(
            top: !isSignedIn,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (isSignedIn) ...[
                        _ProfileHeader(
                          user: user,
                          roleLabel: _roleLabel(l10n, user.role),
                          onTap: () => goTo(AppRoutes.profile),
                        ),
                        const _MenuDivider(
                          key: Key('menu-profile-explore-divider'),
                        ),
                      ],
                      _MenuSection(
                        title: l10n.menuExplore,
                        compactTop: isSignedIn,
                        compactBottom: isSignedIn,
                        children: [
                          _MenuItem(
                            itemKey: const Key('menu-discovery-sessions'),
                            icon: AppIcons.searchSessions,
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
                            itemKey: const Key('menu-discovery-venues'),
                            icon: AppIcons.searchVenues,
                            label: l10n.homeDiscoveryVenues,
                            isActive:
                                isDiscoveryActive('venues') ||
                                isActive(AppRoutes.venues),
                            onTap: () => goTo(
                              AppRoutes.homeForDiscoveryTab('venues'),
                            ),
                          ),
                          _MenuItem(
                            itemKey: const Key('menu-discovery-clubs'),
                            icon: AppIcons.searchClubs,
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
                          if (isSignedIn)
                            _MenuItem(
                              icon: AppIcons.award,
                              label: l10n.navLeaderboard,
                              isActive: isActive(AppRoutes.leaderboard),
                              onTap: () => pushTo(AppRoutes.leaderboard),
                            ),
                        ],
                      ),
                      if (isSignedIn) ...[
                        const _MenuDivider(
                          key: Key('menu-explore-manage-divider'),
                        ),
                        _MenuSection(
                          title: l10n.menuManage,
                          compactTop: true,
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
                              icon: AppIcons.reminders,
                              label: l10n.reminderTitle,
                              isActive: isActive(AppRoutes.reminders),
                              onTap: () => pushTo(AppRoutes.reminders),
                            ),
                          ],
                        ),
                        if (user.isAdmin)
                          _MenuSection(
                            title: 'ADMIN',
                            children: [
                              for (final destination
                                  in AdminWebDestination.values)
                                _MenuItem(
                                  icon: destination.icon,
                                  label: destination.titleFor(
                                    Localizations.localeOf(context),
                                  ),
                                  onTap: () {
                                    closeDrawer();
                                    unawaited(
                                      openAdminWebDestination(
                                        context,
                                        user,
                                        destination,
                                      ),
                                    );
                                  },
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
                            if (isAiAssistantEnabled)
                              _MenuItem(
                                itemKey: const Key('menu-ai-assistant'),
                                icon: AppIcons.sparkles,
                                label: l10n.aiAssistantTitle,
                                isFeatured: true,
                                onTap: openAiAssistant,
                              ),
                            _MenuItem(
                              icon: AppIcons.help,
                              label: l10n.menuHelpFeedback,
                              isActive: isActive(AppRoutes.feedback),
                              onTap: () => pushTo(AppRoutes.feedback),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                key: const Key('menu-sign-in-button'),
                                style: OutlinedButton.styleFrom(
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  closeDrawer();
                                  unawaited(context.push(AppRoutes.signIn));
                                },
                                icon: const Icon(AppIcons.login, size: 18),
                                label: Text(l10n.authSignIn),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FilledButton.icon(
                                key: const Key('menu-sign-up-button'),
                                style: FilledButton.styleFrom(
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  closeDrawer();
                                  unawaited(context.push(AppRoutes.signUp));
                                },
                                icon: const Icon(AppIcons.userPlus, size: 18),
                                label: Text(l10n.authSignUp),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const _MenuDivider(),
                if (isSignedIn) _SignOutButton(onTap: confirmSignOut),
                _MenuFooter(
                  appName: l10n.appName,
                  languageCode: localeCode,
                  themeMode: themeMode,
                  onLanguageTap: () {
                    unawaited(showLanguageSelector(context));
                  },
                  onThemeTap: () {
                    unawaited(showThemeModeSelector(context));
                  },
                ),
              ],
            ),
          ),
          const Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(child: _DrawerEdgeAccent()),
          ),
        ],
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
    UserRole.host => l10n.menuRoleHost,
    UserRole.admin => l10n.menuRoleAdmin,
    UserRole.referee => l10n.menuRoleReferee,
    UserRole.player || UserRole.guest => l10n.menuRolePlayer,
  };
}

/// Brand accent along the drawer's leading edge, matching the web drawer's
/// green-to-blue highlight that fades into the surface.
class _DrawerEdgeAccent extends StatelessWidget {
  const _DrawerEdgeAccent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Container(
      key: const Key('menu-right-edge-accent'),
      width: 2,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.7),
            palette.info.withValues(alpha: 0.34),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
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
    final tint = HomeHeaderTint.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final initials = user.displayName.trim()[0].toUpperCase();
    final hasImage = user.image?.trim().isNotEmpty ?? false;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: tint.drawerHeaderGradient),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          key: const Key('menu-profile-header'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            topInset + AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                foregroundImage: hasImage ? NetworkImage(user.image!) : null,
                child: Text(
                  initials,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 20 / 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 20 / 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roleLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.extension<AppPalette>()!.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.chevronRight),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    this.title,
    this.compactTop = false,
    this.compactBottom = false,
    required this.children,
  });

  final String? title;
  final bool compactTop;
  final bool compactBottom;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: AppSpacing.sm,
      bottom: compactBottom ? AppSpacing.xs : AppSpacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              compactTop ? AppSpacing.sm : AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              // Uppercase + tight tracking reads as a section header at a
              // glance, instead of competing with the 15px item labels below.
              title!.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 16 / 12,
                letterSpacing: 0.4,
                color: Theme.of(
                  context,
                ).extension<AppPalette>()!.mutedForeground,
                fontWeight: FontWeight.w700,
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
    required this.label,
    this.itemKey,
    this.icon,
    this.leading,
    this.isActive = false,
    this.isFeatured = false,
    this.onTap,
  }) : assert(
         icon != null || leading != null,
         'A menu item needs either an icon or a leading widget.',
       );

  final Key? itemKey;
  final IconData? icon;
  final Widget? leading;
  final String label;
  final bool isActive;
  final bool isFeatured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final featuredColor = theme.brightness == Brightness.dark
        ? const Color(0xFFE9D5FF)
        : const Color(0xFF6D28D9);
    final color = isFeatured
        ? featuredColor
        : isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final iconColor = isActive ? theme.colorScheme.onPrimary : color;
    final radius = BorderRadius.circular(AppRadius.xl);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
      ),
      child: Material(
        key: itemKey,
        color: Colors.transparent,
        borderRadius: radius,
        child: Semantics(
          selected: isActive,
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTapTarget,
              ),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: isActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.34)
                      : Colors.transparent,
                ),
                gradient: isActive
                    ? LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                          theme.colorScheme.primary.withValues(alpha: 0.07),
                          palette.brandSurface.withValues(alpha: 0.28),
                        ],
                        stops: const [0, 0.62, 1],
                      )
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (isActive)
                    Positioned(
                      left: -1,
                      child: Container(
                        key: const Key('menu-active-indicator'),
                        width: 3,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(AppRadius.pill),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.colorScheme.primary,
                              palette.info,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.36,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isActive
                                ? theme.colorScheme.primary
                                : palette.muted.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.34,
                                    )
                                  : Colors.transparent,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.2),
                                      blurRadius: 13,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: IconTheme.merge(
                            data: IconThemeData(color: iconColor, size: 20),
                            child: isFeatured
                                ? Icon(
                                    AppIcons.sparkles,
                                    color: iconColor,
                                    size: 20,
                                  )
                                : leading ?? Icon(icon),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              height: 20 / 15,
                              color: color,
                              fontWeight: isFeatured
                                  ? FontWeight.w700
                                  : isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).extension<AppPalette>()!.border,
  );
}

/// Pinned sign-out action at the very bottom of the drawer, above the
/// footer branding row. Deliberately styled like a warning, not a nav
/// item, since it ends the session rather than navigating within it.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          key: const Key('menu-sign-out-button'),
          style: TextButton.styleFrom(
            foregroundColor: mutedColor,
          ),
          onPressed: onTap,
          icon: const Icon(AppIcons.logout, size: 18),
          label: Text(l10n.authSignOut),
        ),
      ),
    );
  }
}

class _MenuFooter extends StatelessWidget {
  const _MenuFooter({
    required this.appName,
    required this.languageCode,
    required this.themeMode,
    required this.onLanguageTap,
    required this.onThemeTap,
  });

  final String appName;
  final String languageCode;
  final ThemeMode themeMode;
  final VoidCallback onLanguageTap;
  final VoidCallback onThemeTap;

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.light => AppIcons.light,
    ThemeMode.dark => AppIcons.dark,
    ThemeMode.system => AppIcons.themeSystem,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final tint = HomeHeaderTint.of(context);
    return Padding(
      key: const Key('menu-footer'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // Rounded-square badge, matching web's top-bar-logo-mark shape.
                Container(
                  width: 26,
                  height: 26,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tint.accent.withValues(alpha: 0.14),
                        tint.soft.withValues(alpha: 0.13),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset('assets/icons/app-logo-96.png'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    l10n.menuFooterYear(DateTime.now().year),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _FooterAction(
            buttonKey: const Key('menu-language-action'),
            icon: AppIcons.language,
            label: languageCode.toUpperCase(),
            tooltip: l10n.languageChangeTooltip,
            onTap: onLanguageTap,
          ),
          _FooterAction(
            buttonKey: const Key('menu-theme-action'),
            icon: _themeIcon(themeMode),
            tooltip: l10n.themeTitle,
            onTap: onThemeTap,
          ),
        ],
      ),
    );
  }
}

/// Compact utility control pinned to the menu footer, sized to the tap-target
/// floor so the short label does not shrink it below 48 px.
class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.buttonKey,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Key buttonKey;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.minTapTarget,
            minHeight: AppSizes.minTapTarget,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 0 : AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: palette.mutedForeground),
                if (label != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.mutedForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
