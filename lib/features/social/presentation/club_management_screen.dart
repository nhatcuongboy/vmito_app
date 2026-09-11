import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_managing_tab.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_member_tab.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_card_parts.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// "My groups": the clubs the viewer manages and the ones they joined.
///
/// Unlike web, the title stays fixed across tabs — web retitles the page per
/// tab, which on mobile repeats the selected tab label right above it.
class ClubManagementScreen extends ConsumerStatefulWidget {
  const ClubManagementScreen({this.initialTab = 'managing', super.key});

  final String initialTab;

  @override
  ConsumerState<ClubManagementScreen> createState() =>
      _ClubManagementScreenState();
}

class _ClubManagementScreenState extends ConsumerState<ClubManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late int _lastIndex;

  int get _requestedIndex => widget.initialTab == 'member' ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: _requestedIndex,
    )..addListener(_onTabChanged);
    _lastIndex = _requestedIndex;
  }

  @override
  void didUpdateWidget(covariant ClubManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabs.index != _requestedIndex) {
      _lastIndex = _requestedIndex;
      _tabs.index = _requestedIndex;
    }
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _tabs.index == _lastIndex || !mounted) return;
    _lastIndex = _tabs.index;
    setState(() {});
    context.replace(
      AppRoutes.manageClubsForTab(_tabs.index == 1 ? 'member' : 'managing'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    // Surfaces waiting work on the tab itself, so a host browsing the
    // "joined" tab still sees that requests came in.
    final waitingCount =
        (ref.watch(incomingClubRequestsProvider).asData?.value.length ?? 0) +
        (isAdmin
            ? ref.watch(pendingClubsProvider).asData?.value.length ?? 0
            : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clubMyGroupsTitle),
        bottom: AppTabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.clubManagingTab,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (waitingCount > 0) ...[
                    const SizedBox(width: 6),
                    Badge.count(
                      key: const Key('club-management-waiting-badge'),
                      count: waitingCount,
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: l10n.clubMemberTab),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0 && ref.watch(canCreateClubProvider)
          ? const _CreateClubFab()
          : null,
      body: TabBarView(
        controller: _tabs,
        children: const [ClubManagingTab(), ClubMemberTab()],
      ),
    );
  }
}

/// Brand-tinted pill FAB, matching the "Tạo giải" action on host tournaments.
class _CreateClubFab extends StatelessWidget {
  const _CreateClubFab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = AppLocalizations.of(context).clubCreate;
    return SizedBox(
      height: 44,
      child: FloatingActionButton.extended(
        key: const Key('club-management-create-fab'),
        heroTag: 'club-management-create-fab',
        tooltip: label,
        onPressed: () => context.push(AppRoutes.createClub),
        backgroundColor: clubPaletteOf(theme).brandSurface,
        foregroundColor: theme.colorScheme.primary,
        elevation: 4,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 13),
        shape: StadiumBorder(
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
        ),
        icon: const Icon(AppIcons.add, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
