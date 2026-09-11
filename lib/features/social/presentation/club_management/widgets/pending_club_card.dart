import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_management_helpers.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_card_parts.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_list_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A newly created club awaiting system-admin approval. Buttons follow the
/// join-request card: reject on the left, approve (primary) on the right.
class PendingClubCard extends ConsumerWidget {
  const PendingClubCard({required this.club, super.key});

  final ClubSummary club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isBusy = ref.watch(clubManagementControllerProvider).isLoading;
    final location = club.location?.trim() ?? '';

    return ClubCardShell(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClubListAvatar(name: club.name, imageUrl: club.heroImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        ClubMeta(icon: AppIcons.mapPin, text: location),
                      ],
                      const SizedBox(height: 2),
                      ClubMeta(
                        icon: AppIcons.user,
                        text: l10n.clubHostedBy(
                          club.hostName ?? l10n.clubNotSpecified,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                    onPressed: isBusy
                        ? null
                        : () => runClubAction(
                            context,
                            () => ref
                                .read(clubManagementControllerProvider.notifier)
                                .approveClub(club.id),
                            l10n.clubActionFailed,
                            success: l10n.clubApproveSuccess,
                          ),
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

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askClubRejectionReason(context);
    if (reason == null || !context.mounted) return;
    await runClubAction(
      context,
      () => ref
          .read(clubManagementControllerProvider.notifier)
          .rejectClub(club.id, reason),
      l10n.clubActionFailed,
      success: l10n.clubRejectSuccess,
    );
  }
}
