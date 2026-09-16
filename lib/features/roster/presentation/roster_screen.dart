import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/roster/presentation/widgets/player_profile_card.dart';
import 'package:vmito_app/features/roster/presentation/widgets/player_profile_form_sheet.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(rosterControllerProvider);
    final controller = ref.read(rosterControllerProvider.notifier);
    final managedClubs = ref.watch(managedClubsProvider).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.rosterSearchPlaceholder,
                  border: InputBorder.none,
                ),
                onChanged: controller.setSearchQuery,
              )
            : Text(l10n.rosterScreenTitle),
        actions: [
          IconButton(
            tooltip: _showSearch ? l10n.commonClose : l10n.commonSearch,
            icon: Icon(_showSearch ? AppIcons.close : AppIcons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  controller.setSearchQuery('');
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPlayerProfileFormSheet(context),
        icon: const Icon(AppIcons.add),
        label: Text(l10n.rosterAddPlayerAction),
      ),
      body: Column(
        children: [
          // Club Filter Chips (scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.commonAll),
                  selected:
                      state.selectedClubFilter == null ||
                      state.selectedClubFilter == 'all',
                  onSelected: (_) => controller.setClubFilter('all'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilterChip(
                  label: Text(l10n.rosterPersonalBadge),
                  selected: state.selectedClubFilter == 'none',
                  onSelected: (_) => controller.setClubFilter('none'),
                ),
                for (final club in managedClubs) ...[
                  const SizedBox(width: AppSpacing.xs),
                  FilterChip(
                    label: Text(l10n.rosterGroupName(club.name)),
                    selected: state.selectedClubFilter == club.id,
                    onSelected: (_) => controller.setClubFilter(club.id),
                  ),
                ],
              ],
            ),
          ),

          // Status segmented buttons (Active vs Promoted vs Archived)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: SegmentedButton<PlayerProfileStatus>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                ),
              ),
              segments: [
                ButtonSegment(
                  value: PlayerProfileStatus.active,
                  label: Text(l10n.rosterStatusActive),
                ),
                ButtonSegment(
                  value: PlayerProfileStatus.promoted,
                  label: Text(l10n.rosterStatusPromoted),
                ),
                ButtonSegment(
                  value: PlayerProfileStatus.archived,
                  label: Text(l10n.rosterStatusArchived),
                ),
              ],
              selected: {state.selectedStatus},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  controller.setStatusFilter(selection.first);
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Player List
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.loadProfiles,
              child: state.isLoading && state.profiles.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null && state.profiles.isEmpty
                  ? AppErrorView(
                      error: state.error!,
                      onRetry: controller.loadProfiles,
                    )
                  : state.profiles.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  AppIcons.user,
                                  size: 48,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  l10n.rosterEmptyListMessage,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.xs,
                        bottom: 80,
                      ),
                      itemCount: state.profiles.length,
                      itemBuilder: (context, index) {
                        final profile = state.profiles[index];
                        return PlayerProfileCard(
                          key: ValueKey(profile.id),
                          profile: profile,
                          onChanged: controller.loadProfiles,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
