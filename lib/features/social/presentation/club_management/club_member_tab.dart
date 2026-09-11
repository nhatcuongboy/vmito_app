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
import 'package:vmito_app/features/social/presentation/club_management/widgets/outgoing_request_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Clubs the viewer has joined (without managing them), then the join
/// requests they are still waiting on — the latter hidden when empty.
class ClubMemberTab extends ConsumerWidget {
  const ClubMemberTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allClubs = ref.watch(myClubsProvider);
    final outgoing = ref.watch(myClubRequestsProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    final l10n = AppLocalizations.of(context);
    final memberClubs = allClubs.whenData(
      (items) => memberOnlyClubs(items, currentUserId: userId),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(myClubsProvider)
          ..invalidate(myClubRequestsProvider);
        await Future.wait([
          ref.read(myClubsProvider.future),
          ref.read(myClubRequestsProvider.future),
        ]);
      },
      child: ListView(
        key: const PageStorageKey('club-member-tab'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          96,
        ),
        children: [
          ClubSectionHeader(
            icon: AppIcons.users,
            title: l10n.clubJoinedGroups,
            count: memberClubs.asData?.value.length,
          ),
          const SizedBox(height: 12),
          memberClubs.when(
            data: (items) => items.isEmpty
                ? ClubEmptyView(
                    icon: AppIcons.users,
                    title: l10n.clubJoinedEmpty,
                    description: l10n.clubJoinedEmptyDesc,
                    action: OutlinedButton(
                      onPressed: () =>
                          context.go(AppRoutes.homeForDiscoveryTab('clubs')),
                      child: Text(l10n.clubBrowse),
                    ),
                  )
                : ClubAdaptiveGrid(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final club = items[i];
                      return ClubListCard(
                        club: club,
                        showHost: true,
                        onTap: () => context.push(
                          AppRoutes.clubDetail(club.slug ?? club.id),
                        ),
                      );
                    },
                  ),
            loading: () => const ClubCardSkeletonList(),
            error: (error, _) => ClubInlineError(
              error: error,
              onRetry: () => ref.invalidate(myClubsProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...clubWaitingSection(
            value: outgoing,
            header: (count) => ClubSectionHeader(
              icon: AppIcons.clock,
              title: l10n.clubAwaitingApproval,
              count: count,
            ),
            body: (items) => ClubAdaptiveGrid(
              itemCount: items.length,
              itemBuilder: (_, i) => OutgoingRequestCard(request: items[i]),
            ),
            onRetry: () => ref.invalidate(myClubRequestsProvider),
          ),
        ],
      ),
    );
  }
}
