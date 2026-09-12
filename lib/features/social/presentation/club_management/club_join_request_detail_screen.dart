import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_management_helpers.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/registration_status_badge.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_action_bar.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_applicant_header.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_detail_scaffold.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_info_row.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_not_found_view.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_note_card.dart';

/// Full detail of one club join request, so a host can review everything the
/// compact `IncomingRequestCard` had to abbreviate before deciding.
///
/// There is no fetch-by-id endpoint for a join request, so this screen finds
/// [requestId] inside [clubJoinRequestsProvider], the same per-club list the
/// old `ClubRequestsTab` already loads.
class ClubJoinRequestDetailScreen extends ConsumerWidget {
  const ClubJoinRequestDetailScreen({
    required this.clubId,
    required this.requestId,
    required this.canDecide,
    super.key,
  });

  final String clubId;
  final String requestId;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final requests = ref.watch(clubJoinRequestsProvider(clubId));
    return RequestDetailScaffold(
      title: l10n.clubJoinRequestDetailTitle,
      body: requests.when(
        data: (items) {
          ClubJoinRequest? match;
          for (final item in items) {
            if (item.id == requestId) {
              match = item;
              break;
            }
          }
          if (match == null) return const RequestNotFoundView();
          return _ClubRequestBody(
            clubId: clubId,
            request: match,
            canDecide: canDecide,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(clubJoinRequestsProvider(clubId)),
        ),
      ),
    );
  }
}

class _ClubRequestBody extends ConsumerWidget {
  const _ClubRequestBody({
    required this.clubId,
    required this.request,
    required this.canDecide,
  });

  final String clubId;
  final ClubJoinRequest request;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isBusy = ref.watch(clubManagementControllerProvider).isLoading;
    final status = _statusOf(request.status);
    final isPending = status == RegistrationStatus.pending;
    final message = request.message?.trim() ?? '';
    final response = request.response?.trim() ?? '';
    final club = request.club;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              RequestApplicantHeader(
                name: request.userName,
                imageUrl: request.userImage,
                onTapName: request.userId.isEmpty
                    ? null
                    : () =>
                          context.push(AppRoutes.publicProfile(request.userId)),
                statusBadge: RegistrationStatusBadge(status: status),
                submittedLabel: clubRequestSubmittedLabel(
                  context,
                  request.createdAt,
                ),
                summary: [
                  if ((request.sessionsPlayedCount ?? 0) > 0)
                    _SummaryChip(
                      label: l10n.clubSessionsPlayed(
                        request.sessionsPlayedCount!,
                      ),
                    ),
                ],
              ),
              RequestInfoList(
                rows: [
                  if (club?.name.isNotEmpty ?? false)
                    RequestInfoRow(
                      icon: AppIcons.clubs,
                      label: l10n.joinRequestDetailLabelClub,
                      value: club!.name,
                      onTap: () => context.push(
                        AppRoutes.clubDetail(club.slug ?? club.id),
                      ),
                    ),
                  if (club?.hostName?.isNotEmpty ?? false)
                    RequestInfoRow(
                      icon: AppIcons.user,
                      label: l10n.joinRequestDetailLabelHost,
                      value: club!.hostName!,
                    ),
                  RequestInfoRow(
                    icon: AppIcons.mail,
                    label: l10n.joinRequestDetailLabelEmail,
                    value: request.userEmail,
                  ),
                ],
              ),
              if (message.isNotEmpty)
                RequestNoteCard(
                  label: l10n.joinRequestDetailLabelMessage,
                  content: message,
                ),
              if (!isPending && response.isNotEmpty)
                RequestNoteCard(
                  label: l10n.joinRequestDetailLabelResponse,
                  content: response,
                ),
            ],
          ),
        ),
        if (canDecide && isPending)
          RequestActionBar(
            busy: isBusy,
            onApprove: () => _approve(context, ref),
            onReject: () => _reject(context, ref),
          ),
      ],
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .approveRequest(clubId, request.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.clubApproveSuccess)));
      unawaited(Navigator.of(context).maybePop());
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.clubActionFailed)));
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askClubRejectionReason(context);
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .rejectRequest(clubId, request.id, response: reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.clubRejectSuccess)));
      unawaited(Navigator.of(context).maybePop());
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.clubActionFailed)));
      }
    }
  }
}

RegistrationStatus _statusOf(String status) => switch (status.toUpperCase()) {
  'APPROVED' => RegistrationStatus.approved,
  'REJECTED' => RegistrationStatus.rejected,
  _ => RegistrationStatus.pending,
};

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
