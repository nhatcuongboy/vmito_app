import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/registration/application/my_join_requests_controller.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';
import 'package:vmito_app/shared/widgets/app_sheet_grabber.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_domain/vmito_domain.dart';

Future<void> showMyJoinRequestsSheet(
  BuildContext context, {
  FutureOr<void> Function()? onMutated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MyJoinRequestsSheet(onMutated: onMutated),
  );
}

class MyJoinRequestsSheet extends ConsumerStatefulWidget {
  const MyJoinRequestsSheet({this.onMutated, super.key});

  final FutureOr<void> Function()? onMutated;

  @override
  ConsumerState<MyJoinRequestsSheet> createState() =>
      _MyJoinRequestsSheetState();
}

class _MyJoinRequestsSheetState extends ConsumerState<MyJoinRequestsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(myJoinRequestsControllerProvider.notifier).refresh(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(myJoinRequestsRealtimeProvider);
    final state = ref.watch(myJoinRequestsControllerProvider);
    final controller = ref.read(myJoinRequestsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    ref.listen(myJoinRequestsControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorUnknown)),
        );
      }
    });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          child: Column(
            children: [
              const AppSheetGrabber(),
              _SheetHeader(total: state.total),
              Expanded(
                child: _RequestsBody(
                  state: state,
                  scrollController: scrollController,
                  onRetry: controller.refresh,
                  onPrevious: controller.previousPage,
                  onNext: controller.nextPage,
                  onViewSession: _viewSession,
                  onWithdraw: _confirmWithdraw,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewSession(MyJoinRequest request) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(router.push(AppRoutes.sessionDetail(request.session.id)));
    });
  }

  Future<void> _confirmWithdraw(MyJoinRequest request) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.myJoinRequestsWithdrawTitle,
      content: l10n.myJoinRequestsWithdrawConfirm,
      confirmLabel: l10n.myJoinRequestsWithdraw,
    );
    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(myJoinRequestsControllerProvider.notifier)
        .withdraw(request);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.myJoinRequestsWithdrawDone)),
      );
      await widget.onMutated?.call();
    } else if (ref.read(myJoinRequestsControllerProvider).error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorUnknown)),
      );
    }
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSheetHeader(
      title: l10n.myJoinRequestsTitle,
      subtitle: l10n.myJoinRequestsDescription(total),
      closeButtonKey: const Key('my-join-requests-close'),
    );
  }
}

class _RequestsBody extends StatelessWidget {
  const _RequestsBody({
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
    required this.onViewSession,
    required this.onWithdraw,
  });

  final MyJoinRequestsState state;
  final ScrollController scrollController;
  final Future<void> Function() onRetry;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final ValueChanged<MyJoinRequest> onViewSession;
  final Future<void> Function(MyJoinRequest) onWithdraw;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && !state.hasLoaded) {
      return const AppLoadingView();
    }
    if (state.error != null && state.requests.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 280,
            child: AppErrorView(error: state.error!, onRetry: onRetry),
          ),
        ],
      );
    }
    if (state.requests.isEmpty) {
      return _EmptyRequestsView(
        scrollController: scrollController,
        onRefresh: onRetry,
      );
    }

    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: state.requests.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index < state.requests.length) {
          final request = state.requests[index];
          return _JoinRequestCard(
            request: request,
            busy: state.withdrawingSessionId == request.session.id,
            onViewSession: () => onViewSession(request),
            onWithdraw: () => onWithdraw(request),
          );
        }
        return _Pagination(
          page: state.page,
          totalPages: state.totalPages,
          busy: state.isLoading || state.isLoadingMore,
          onPrevious: onPrevious,
          onNext: onNext,
        );
      },
    );
  }
}

class _JoinRequestCard extends StatelessWidget {
  const _JoinRequestCard({
    required this.request,
    required this.busy,
    required this.onViewSession,
    required this.onWithdraw,
  });

  final MyJoinRequest request;
  final bool busy;
  final VoidCallback onViewSession;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final session = request.session;
    final startTime = session.startTime;
    final requestedAt = request.requestedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    session.name,
                    key: ValueKey('my-join-request-title-${session.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (requestedAt != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    DateFormat('dd/MM/yyyy').format(requestedAt.toLocal()),
                    key: ValueKey('my-join-request-date-${session.id}'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: palette.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
            if (session.locationLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                session.locationLabel!,
                key: ValueKey('my-join-request-location-${session.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  color: palette.mutedForeground,
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.myJoinRequestsLocationNotUpdated,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  color: palette.mutedForeground,
                ),
              ),
            ],
            if (startTime != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                DateFormat(
                  'MMM d, HH:mm',
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(startTime.toLocal()),
                key: ValueKey('my-join-request-start-time-${session.id}'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  color: palette.mutedForeground,
                ),
              ),
            ],
            if (request.players.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              ...request.players.map(
                (player) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PlayerStatusRow(
                    sessionId: session.id,
                    player: player,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('view-my-join-request-${session.id}'),
                  onPressed: busy ? null : onViewSession,
                  icon: const Icon(AppIcons.externalLink),
                  label: Text(
                    l10n.myJoinRequestsViewSession,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (request.hasPending)
                  OutlinedButton(
                    key: ValueKey('withdraw-my-join-request-${session.id}'),
                    onPressed: busy ? null : onWithdraw,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.45),
                      ),
                    ),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.myJoinRequestsWithdraw,
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerStatusRow extends StatelessWidget {
  const _PlayerStatusRow({required this.sessionId, required this.player});

  final String sessionId;
  final MyJoinRequestPlayer player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final number = player.playerNumber;
    final name = player.name?.trim();
    final playerName = name == null || name.isEmpty
        ? number == null
              ? l10n.mySessionsUnknownPlayer
              : l10n.myJoinRequestsPlayerNumber(number)
        : name;

    final (statusText, statusColor) = switch (player.registrationStatus) {
      RegistrationStatus.approved => (
        l10n.registrationStatusApproved,
        palette.success,
      ),
      RegistrationStatus.pending => (
        l10n.registrationStatusPending,
        palette.warning,
      ),
      RegistrationStatus.rejected => (
        l10n.registrationStatusRejected,
        theme.colorScheme.error,
      ),
    };

    return Material(
      color: palette.muted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(
          AppRoutes.sessionJoinRequestDetail(
            sessionId,
            player.id,
            asApplicant: true,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName,
                      key: ValueKey('my-join-request-player-${player.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (player.level != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        levelShortLabel(player.level!) ?? '${player.level}',
                        key: ValueKey('my-join-request-level-${player.id}'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: palette.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  statusText,
                  key: ValueKey('my-join-request-status-${player.id}'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.busy,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final bool busy;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox(height: AppSpacing.sm);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            key: const Key('my-join-requests-previous'),
            onPressed: busy || page <= 1 ? null : () => unawaited(onPrevious()),
            child: Text(
              l10n.myJoinRequestsPrevious,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l10n.myJoinRequestsPage(page, totalPages),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          OutlinedButton(
            key: const Key('my-join-requests-next'),
            onPressed: busy || page >= totalPages
                ? null
                : () => unawaited(onNext()),
            child: Text(
              l10n.myJoinRequestsNext,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequestsView extends StatelessWidget {
  const _EmptyRequestsView({
    required this.scrollController,
    required this.onRefresh,
  });

  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.clipboardList,
                    size: 48,
                    color: palette.mutedForeground,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.myJoinRequestsEmpty,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.myJoinRequestsEmptyDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(AppIcons.refresh),
                    label: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
