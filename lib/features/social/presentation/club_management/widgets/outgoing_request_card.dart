import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_management_helpers.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_card_parts.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_list_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

/// A join request the viewer sent and is still waiting on.
///
/// No "Pending" pill — the section title already says it, and the pill used
/// to squeeze long club names onto two lines. The card itself opens the club;
/// withdrawing is a quiet footer action rather than a primary-coloured one.
class OutgoingRequestCard extends ConsumerWidget {
  const OutgoingRequestCard({required this.request, super.key});

  final ClubJoinRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = clubPaletteOf(theme);
    final isBusy = ref.watch(clubManagementControllerProvider).isLoading;
    final club = request.club;
    final name = club?.name ?? '';
    final message = request.message?.trim() ?? '';

    return ClubCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: club == null
                ? null
                : () =>
                      context.push(AppRoutes.clubDetail(club.slug ?? club.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  ClubListAvatar(name: name, imageUrl: club?.image),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClubMeta(
                          icon: AppIcons.user,
                          text: l10n.clubHostedBy(
                            club?.hostName ?? l10n.clubNotSpecified,
                          ),
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '“$message”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
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
          ),
          Divider(height: 1, thickness: 1, color: palette.border),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
            child: Row(
              children: [
                Expanded(
                  child: ClubMeta(
                    icon: AppIcons.clock,
                    text: clubRequestSubmittedLabel(context, request.createdAt),
                  ),
                ),
                IconButton(
                  tooltip: l10n.joinRequestDetailViewDetail,
                  visualDensity: VisualDensity.compact,
                  color: palette.mutedForeground,
                  onPressed: () => context.push(
                    AppRoutes.clubJoinRequestDetail(
                      request.clubId,
                      request.id,
                      asApplicant: true,
                    ),
                  ),
                  icon: const Icon(AppIcons.eye, size: 18),
                ),
                TextButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => _withdraw(context, ref, name),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.mutedForeground,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(AppIcons.undo, size: 16),
                  label: Text(l10n.clubWithdrawShort),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.clubWithdrawTitle,
      content: l10n.clubWithdrawConfirm(name),
      confirmLabel: l10n.clubWithdrawRequest,
    );
    if (confirmed != true || !context.mounted) return;
    await runClubAction(
      context,
      () => ref
          .read(clubManagementControllerProvider.notifier)
          .cancelJoinRequest(request.clubId),
      l10n.clubActionFailed,
      success: l10n.clubWithdrawSuccess,
    );
  }
}
