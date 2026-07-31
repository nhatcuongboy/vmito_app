import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ClubManagementScreen extends ConsumerWidget {
  const ClubManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(managedClubsProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.clubManageTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createClub),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.clubCreate),
      ),
      body: clubs.when(
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(managedClubsProvider.future),
          child: items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .6,
                      child: Center(child: Text(l10n.clubManageEmpty)),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    96,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _ManagedClubCard(club: items[index]),
                ),
        ),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(managedClubsProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ManagedClubCard extends ConsumerWidget {
  const _ManagedClubCard({required this.club});

  final ClubSummary club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: club.heroImage == null
              ? null
              : CachedNetworkImageProvider(club.heroImage!),
          child: club.heroImage == null
              ? const Icon(Icons.groups_outlined)
              : null,
        ),
        title: Text(club.name),
        subtitle: Text(
          '${l10n.socialMemberCount(club.memberCount)} • '
          '${_statusLabel(l10n, club.status)}',
        ),
        onTap: () => context.push(AppRoutes.manageClub(club.id)),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'edit') {
              await context.push(AppRoutes.editClub(club.id));
            } else if (action == 'delete') {
              await _confirmDelete(context, ref);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
            PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
    'PENDING' => l10n.clubStatusPending,
    'REJECTED' => l10n.clubStatusRejected,
    _ => l10n.clubStatusApproved,
  };

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clubDeleteTitle),
        content: Text(l10n.clubDeleteConfirm(club.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .deleteClub(club.id);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}
