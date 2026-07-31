import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ClubRequestsTab extends ConsumerWidget {
  const ClubRequestsTab({required this.clubId, super.key});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(clubJoinRequestsProvider(clubId));
    final l10n = AppLocalizations.of(context);
    return requests.when(
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(clubJoinRequestsProvider(clubId).future),
        child: items.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * .55,
                    child: Center(child: Text(l10n.clubRequestsEmpty)),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _RequestCard(clubId: clubId, request: items[index]),
              ),
      ),
      error: (error, _) => AppErrorView(
        error: error,
        onRetry: () => ref.invalidate(clubJoinRequestsProvider(clubId)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.clubId, required this.request});

  final String clubId;
  final ClubJoinRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: request.userImage == null
                    ? null
                    : CachedNetworkImageProvider(request.userImage!),
                child: request.userImage == null
                    ? const Icon(Icons.person_outline_rounded)
                    : null,
              ),
              title: Text(request.userName),
              subtitle: Text(
                '${request.userEmail}\n'
                '${Dates.dateOnly(request.createdAt, locale: locale)}',
              ),
              isThreeLine: true,
            ),
            if (request.message?.trim().isNotEmpty ?? false) ...[
              Text(request.message!),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  child: Text(l10n.hostManageReject),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => ref
                      .read(clubManagementControllerProvider.notifier)
                      .approveRequest(clubId, request.id),
                  child: Text(l10n.hostManageApprove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clubRejectRequest),
        content: TextField(
          controller: controller,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(hintText: l10n.clubRejectReason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.hostManageReject),
          ),
        ],
      ),
    );
    controller.dispose();
    if (response == null) return;
    await ref
        .read(clubManagementControllerProvider.notifier)
        .rejectRequest(clubId, request.id, response: response);
  }
}
