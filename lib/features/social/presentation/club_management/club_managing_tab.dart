import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_adaptive_grid.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_list_card.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_management_states.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_section_header.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/incoming_request_card.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/managed_club_more_menu.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/pending_club_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Work waiting on the host comes first: join requests, then (for system
/// admins) clubs awaiting approval, then the managed clubs. Web lists the
/// clubs first; on a phone that pushes the actionable items below the fold
/// as soon as a host runs two or three clubs. Both waiting sections hide
/// when empty rather than spending a panel on "nothing here".
class ClubManagingTab extends ConsumerWidget {
  const ClubManagingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(managedClubsProvider);
    final incoming = ref.watch(incomingClubRequestsProvider);
    final pending = ref.watch(pendingClubsProvider);
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final canCreate = ref.watch(canCreateClubProvider);
    final l10n = AppLocalizations.of(context);

    Future<void> refresh() async {
      ref
        ..invalidate(managedClubsProvider)
        ..invalidate(incomingClubRequestsProvider)
        ..invalidate(pendingClubsProvider);
      await Future.wait([
        ref.read(managedClubsProvider.future),
        ref.read(incomingClubRequestsProvider.future),
        if (isAdmin) ref.read(pendingClubsProvider.future),
      ]);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        key: const PageStorageKey('club-managing-tab'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          96,
        ),
        children: [
          ...clubWaitingSection(
            value: incoming,
            header: (count) => ClubSectionHeader(
              icon: AppIcons.clipboardList,
              title: l10n.clubIncomingRequests,
              count: count,
              needsAttention: true,
            ),
            body: (items) => ClubAdaptiveGrid(
              itemCount: items.length,
              itemBuilder: (_, i) => IncomingRequestCard(request: items[i]),
            ),
            onRetry: () => ref.invalidate(incomingClubRequestsProvider),
          ),
          if (isAdmin)
            ...clubWaitingSection(
              value: pending,
              header: (count) => ClubSectionHeader(
                icon: AppIcons.shieldCheck,
                title: l10n.clubAdminApprovalTitle,
                count: count,
                needsAttention: true,
              ),
              body: (items) => ClubAdaptiveGrid(
                maxExtent: 540,
                itemCount: items.length,
                itemBuilder: (_, i) => PendingClubCard(club: items[i]),
              ),
              onRetry: () => ref.invalidate(pendingClubsProvider),
            ),
          ClubSectionHeader(
            icon: AppIcons.shield,
            title: isAdmin
                ? l10n.clubAdminManagingGroups
                : l10n.clubManagingGroups,
            count: clubs.asData?.value.length,
          ),
          const SizedBox(height: 12),
          clubs.when(
            data: (items) => items.isEmpty
                ? ClubEmptyView(
                    icon: AppIcons.shield,
                    title: isAdmin
                        ? l10n.clubNoSystemGroups
                        : l10n.clubManageEmpty,
                    description: canCreate ? l10n.clubManageEmptyDesc : null,
                    action: canCreate
                        ? FilledButton.icon(
                            onPressed: () => context.push(AppRoutes.createClub),
                            icon: const Icon(AppIcons.add),
                            label: Text(l10n.clubCreateFirst),
                          )
                        : null,
                  )
                : ClubAdaptiveGrid(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final club = items[i];
                      return ClubListCard(
                        club: club,
                        // The viewer's own name adds nothing; other hosts'
                        // names matter to moderators and system admins.
                        showHost: club.hostUserId != user?.id,
                        onTap: () =>
                            context.push(AppRoutes.manageClub(club.id)),
                        trailing: ManagedClubMoreMenu(club: club),
                      );
                    },
                  ),
            loading: () => const ClubCardSkeletonList(),
            error: (error, _) => ClubInlineError(
              error: error,
              onRetry: () => ref.invalidate(managedClubsProvider),
            ),
          ),
        ],
      ),
    );
  }
}
