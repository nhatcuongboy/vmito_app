import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

export 'package:vmito_app/features/home/domain/home_discovery_tab.dart';

extension HomeDiscoveryTabLabel on HomeDiscoveryTab {
  String label(AppLocalizations l10n) => switch (this) {
    HomeDiscoveryTab.sessions => l10n.homeDiscoverySessions,
    HomeDiscoveryTab.venues => l10n.homeDiscoveryVenues,
    HomeDiscoveryTab.clubs => l10n.homeDiscoveryClubs,
    HomeDiscoveryTab.tournaments => l10n.homeDiscoveryTournaments,
  };
}

class HomeDiscoveryTabs extends StatelessWidget {
  const HomeDiscoveryTabs({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final HomeDiscoveryTab selected;
  final ValueChanged<HomeDiscoveryTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: palette.border.withValues(alpha: 0.6)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in HomeDiscoveryTab.values)
              Semantics(
                button: true,
                selected: selected == tab,
                child: InkWell(
                  key: Key('home-discovery-tab-${tab.name}'),
                  onTap: () => onSelected(tab),
                  child: AnimatedContainer(
                    key: selected == tab
                        ? Key('home-discovery-indicator-${tab.name}')
                        : null,
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md,
                      AppSpacing.sm + 2,
                      tab == HomeDiscoveryTab.sessions
                          ? AppSpacing.sm
                          : AppSpacing.md,
                      AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 2,
                          color: selected == tab
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tab.label(l10n),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 20 / 15,
                            color: selected == tab
                                ? theme.colorScheme.primary
                                : palette.mutedForeground,
                            fontWeight: selected == tab
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        // A filled flame keeps the accent colour inside the
                        // glyph, without a separate circular background.
                        if (tab == HomeDiscoveryTab.sessions) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            AppIcons.flameFilled,
                            size: 16,
                            color: Color(0xFFFF6B35),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
