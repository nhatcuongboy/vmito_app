import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/presentation/widgets/club_announcements_tab.dart';
import 'package:vmito_app/features/social/presentation/widgets/club_members_tab.dart';
import 'package:vmito_app/features/social/presentation/widgets/club_requests_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ClubManagementDetailScreen extends ConsumerWidget {
  const ClubManagementDetailScreen({required this.clubId, super.key});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(managedClubProvider(clubId));
    final l10n = AppLocalizations.of(context);
    return club.when(
      data: (value) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(value.name),
            actions: [
              IconButton(
                tooltip: l10n.commonEdit,
                onPressed: () => context.push(AppRoutes.editClub(clubId)),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
            bottom: TabBar(
              tabs: [
                Tab(text: l10n.clubMembers),
                Tab(text: l10n.clubRequests),
                Tab(text: l10n.clubAnnouncements),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ClubMembersTab(clubId: clubId),
              ClubRequestsTab(clubId: clubId),
              ClubAnnouncementsTab(clubId: clubId),
            ],
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(managedClubProvider(clubId)),
        ),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
