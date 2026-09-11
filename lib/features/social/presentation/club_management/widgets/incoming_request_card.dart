import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_management_helpers.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_card_parts.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A join request waiting on the host. The requester row opens their public
/// profile so the host can vet them before deciding.
class IncomingRequestCard extends ConsumerWidget {
  const IncomingRequestCard({required this.request, super.key});

  final ClubJoinRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = clubPaletteOf(theme);
    final isBusy = ref.watch(clubManagementControllerProvider).isLoading;
    final message = request.message?.trim() ?? '';
    final details = [
      if (request.club?.name.isNotEmpty ?? false) request.club!.name,
      clubRequestSubmittedLabel(context, request.createdAt),
      if ((request.sessionsPlayedCount ?? 0) > 0)
        l10n.clubSessionsPlayed(request.sessionsPlayedCount!),
    ].join(' · ');

    return ClubCardShell(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: request.userId.isEmpty
                  ? null
                  : () => context.push(AppRoutes.publicProfile(request.userId)),
              child: Row(
                children: [
                  UserAvatar(
                    name: request.userName,
                    imageUrl: request.userImage,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: palette.mutedForeground,
                  ),
                ],
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: palette.muted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  '“$message”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : () => _reject(context, ref),
                    child: Text(l10n.clubReject),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: isBusy ? null : () => _approve(context, ref),
                    child: Text(l10n.clubApprove),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return runClubAction(
      context,
      () => ref
          .read(clubManagementControllerProvider.notifier)
          .approveRequest(request.clubId, request.id),
      l10n.clubActionFailed,
      success: l10n.clubApproveSuccess,
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askClubRejectionReason(context);
    if (reason == null || !context.mounted) return;
    await runClubAction(
      context,
      () => ref
          .read(clubManagementControllerProvider.notifier)
          .rejectRequest(request.clubId, request.id, response: reason),
      l10n.clubActionFailed,
      success: l10n.clubRejectSuccess,
    );
  }
}
