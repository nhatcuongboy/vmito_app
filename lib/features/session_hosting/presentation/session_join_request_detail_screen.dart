import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/registration_status_badge.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_action_bar.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_applicant_header.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_detail_scaffold.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_info_row.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_not_found_view.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Full detail of one session join request. Mirrors
/// `ClubJoinRequestDetailScreen`'s layout on the [RequestDetailScaffold]
/// primitives, but sources data from [sessionDetailProvider] rather than a
/// join-request list: `PendingJoinRequest` (used by the aggregate pending
/// sheet and notifications) and `SessionPlayer` (used by the host roster) are
/// two different models for the same underlying registration, and both carry
/// enough to key into the session — so this screen just refetches the whole
/// session and finds the player, the same "one REST call" pattern every
/// other detail screen in the app already follows.
class SessionJoinRequestDetailScreen extends ConsumerWidget {
  const SessionJoinRequestDetailScreen({
    required this.sessionId,
    required this.requestId,
    required this.canDecide,
    super.key,
  });

  final String sessionId;
  final String requestId;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionDetailProvider(sessionId));
    return RequestDetailScaffold(
      title: l10n.sessionJoinRequestDetailTitle,
      body: session.when(
        data: (value) {
          SessionPlayer? match;
          for (final player in value.players) {
            if (player.id == requestId) {
              match = player;
              break;
            }
          }
          if (match == null) return const RequestNotFoundView();
          return _SessionRequestBody(
            sessionId: sessionId,
            sessionName: value.name,
            venueName: value.venue?.name,
            startTime: value.startTime,
            player: match,
            canDecide: canDecide,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(sessionDetailProvider(sessionId)),
        ),
      ),
    );
  }
}

class _SessionRequestBody extends ConsumerWidget {
  const _SessionRequestBody({
    required this.sessionId,
    required this.sessionName,
    required this.venueName,
    required this.startTime,
    required this.player,
    required this.canDecide,
  });

  final String sessionId;
  final String sessionName;
  final String? venueName;
  final DateTime? startTime;
  final SessionPlayer player;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isBusy = ref
        .watch(hostSessionManagementControllerProvider(sessionId))
        .isLoading;
    final isPending = player.isPendingApproval;
    final name = player.displayName ?? l10n.mySessionsUnknownPlayer;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final timeLabel = startTime == null
        ? null
        : DateFormat.yMd(locale).add_Hm().format(startTime!.toLocal());

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              RequestApplicantHeader(
                name: name,
                imageUrl: player.userImage,
                gender: player.gender?.name.toUpperCase(),
                onTapName: player.userId == null
                    ? null
                    : () =>
                          context.push(AppRoutes.publicProfile(player.userId!)),
                statusBadge: RegistrationStatusBadge(
                  status: player.registrationStatus,
                ),
                summary: [
                  if (player.gender != null)
                    _SummaryChip(label: _genderLabel(l10n, player.gender!)),
                  if (player.level != null)
                    _SummaryChip(
                      label:
                          levelShortLabel(player.level!) ?? '${player.level}',
                    ),
                  if (player.isClubMember &&
                      (player.clubName?.isNotEmpty ?? false))
                    _SummaryChip(label: player.clubName!),
                ],
              ),
              RequestInfoList(
                rows: [
                  RequestInfoRow(
                    icon: AppIcons.sessions,
                    label: l10n.joinRequestDetailLabelSession,
                    value: sessionName,
                    onTap: () =>
                        context.push(AppRoutes.sessionDetail(sessionId)),
                  ),
                  if (venueName?.isNotEmpty ?? false)
                    RequestInfoRow(
                      icon: AppIcons.venue,
                      label: l10n.joinRequestDetailLabelVenue,
                      value: venueName!,
                    ),
                  if (timeLabel != null)
                    RequestInfoRow(
                      icon: AppIcons.clock,
                      label: l10n.joinRequestDetailLabelTime,
                      value: timeLabel,
                    ),
                  if (player.playerNumber != null)
                    RequestInfoRow(
                      icon: AppIcons.tag,
                      label: l10n.joinRequestDetailLabelPlayer,
                      value: '#${player.playerNumber}',
                    ),
                  if (player.phone?.isNotEmpty ?? false)
                    RequestInfoRow(
                      icon: AppIcons.phone,
                      label: l10n.joinRequestDetailLabelPhone,
                      value: player.phone!,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (canDecide && isPending)
          RequestActionBar(
            busy: isBusy,
            onApprove: () => _decide(context, ref, approved: true),
            onReject: () => _decide(context, ref, approved: false),
          ),
      ],
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approved,
  }) async {
    final l10n = AppLocalizations.of(context);
    final succeeded = await ref
        .read(hostSessionManagementControllerProvider(sessionId).notifier)
        .updateRegistration(player.id, approved: approved);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? (approved
                    ? l10n.notificationApproveSuccess
                    : l10n.notificationRejectSuccess)
              : l10n.errorUnknown,
        ),
      ),
    );
    if (succeeded) unawaited(Navigator.of(context).maybePop());
  }
}

String _genderLabel(AppLocalizations l10n, Gender gender) => switch (gender) {
  Gender.male => l10n.genderMale,
  Gender.female => l10n.genderFemale,
  Gender.other => l10n.genderOther,
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
