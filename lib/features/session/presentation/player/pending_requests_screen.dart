import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

class PendingRequestsState {
  const PendingRequestsState({
    this.requests = const [],
    this.page = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasLoaded = false,
    this.actingRequestId,
    this.error,
  });

  final List<PendingJoinRequest> requests;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasLoaded;
  final String? actingRequestId;
  final Object? error;

  bool get hasMore => page < totalPages;

  PendingRequestsState copyWith({
    List<PendingJoinRequest>? requests,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasLoaded,
    String? actingRequestId,
    bool clearActingRequest = false,
    Object? error,
    bool clearError = false,
  }) => PendingRequestsState(
    requests: requests ?? this.requests,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    actingRequestId: clearActingRequest
        ? null
        : actingRequestId ?? this.actingRequestId,
    error: clearError ? null : error ?? this.error,
  );
}

class PendingRequestsNotifier extends Notifier<PendingRequestsState> {
  static const pageSize = 20;

  @override
  PendingRequestsState build() => const PendingRequestsState();

  Future<void> loadInitial() async {
    if (!state.hasLoaded && !state.isLoading) await _load(reset: true);
  }

  Future<void> refresh() => _load(reset: true, silent: state.hasLoaded);

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await _load(reset: false);
  }

  Future<void> decideRequest(
    PendingJoinRequest request, {
    required bool approved,
  }) async {
    if (state.actingRequestId != null) return;
    state = state.copyWith(actingRequestId: request.id, clearError: true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .updateRegistration(
            request.sessionId,
            request.id,
            approved: approved,
          );
      await _load(reset: true, silent: true);
      unawaited(
        ref
            .read(mySessionsControllerProvider(MySessionScope.hosted).notifier)
            .refreshIfLoaded(),
      );
    } on Object catch (error) {
      state = state.copyWith(error: error, clearActingRequest: true);
    }
  }

  Future<void> _load({required bool reset, bool silent = false}) async {
    final nextPage = reset ? 1 : state.page + 1;
    state = state.copyWith(
      isLoading: reset && !silent,
      isLoadingMore: !reset,
      clearError: true,
    );

    try {
      final repository = ref.read(sessionRepositoryProvider);
      final page = await repository.pendingJoinRequests(
        page: nextPage,
        limit: pageSize,
      );
      final items = reset ? page.items : [...state.requests, ...page.items];
      state = state.copyWith(
        requests: items,
        page: page.page,
        totalPages: page.totalPages,
        isLoading: false,
        isLoadingMore: false,
        hasLoaded: true,
        clearActingRequest: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        error: error,
        isLoading: false,
        isLoadingMore: false,
        hasLoaded: true,
        clearActingRequest: true,
      );
    }
  }
}

final pendingRequestsControllerProvider =
    NotifierProvider<PendingRequestsNotifier, PendingRequestsState>(
      PendingRequestsNotifier.new,
    );

Future<void> showPendingRequestsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PendingRequestsSheet(),
  );
}

class PendingRequestsSheet extends ConsumerStatefulWidget {
  const PendingRequestsSheet({super.key});

  @override
  ConsumerState<PendingRequestsSheet> createState() =>
      _PendingRequestsSheetState();
}

class _PendingRequestsSheetState extends ConsumerState<PendingRequestsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(pendingRequestsControllerProvider.notifier).loadInitial(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(pendingRequestsControllerProvider);
    final controller = ref.read(pendingRequestsControllerProvider.notifier);

    ref.listen(pendingRequestsControllerProvider, (previous, next) {
      if (next.error != null &&
          next.error != previous?.error &&
          next.requests.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorUnknown)));
      }
    });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, sheetScrollController) {
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          child: Column(
            children: [
              _PendingRequestsSheetHeader(
                title: l10n.mySessionsPendingRequests,
              ),
              Expanded(
                child: _PendingRequestsBody(
                  state: state,
                  scrollController: sheetScrollController,
                  onRetry: controller.refresh,
                  onLoadMore: controller.loadMore,
                  onDecision: (request, {required approved}) => unawaited(
                    controller.decideRequest(request, approved: approved),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingRequestsSheetHeader extends StatelessWidget {
  const _PendingRequestsSheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: const Key('pending-requests-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(AppIcons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestsBody extends StatelessWidget {
  const _PendingRequestsBody({
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.onLoadMore,
    required this.onDecision,
  });

  final PendingRequestsState state;
  final ScrollController scrollController;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLoadMore;
  final void Function(PendingJoinRequest request, {required bool approved})
  onDecision;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && !state.hasLoaded) return const AppLoadingView();
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
      return _EmptyPendingRequestsView(
        scrollController: scrollController,
        onRefresh: onRetry,
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 500) {
          unawaited(onLoadMore());
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRetry,
        child: ListView.separated(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          itemCount: state.requests.length + (state.isLoadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            if (index == state.requests.length) {
              return const SizedBox(height: 64, child: AppLoadingView());
            }
            final request = state.requests[index];
            return _PendingRequestCard(
              request: request,
              busy: state.actingRequestId == request.id,
              onDecision: (approved) => onDecision(request, approved: approved),
            );
          },
        ),
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.request,
    required this.busy,
    required this.onDecision,
  });

  final PendingJoinRequest request;
  final bool busy;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = request.startTime == null
        ? null
        : DateFormat.yMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).add_Hm().format(request.startTime!.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.playerName?.trim().isNotEmpty ?? false
                  ? request.playerName!
                  : l10n.mySessionsUnknownPlayer,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(request.sessionName),
            if (request.venueName != null) Text(request.venueName!),
            if (date != null) Text(date),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('reject-request-${request.id}'),
                    onPressed: busy ? null : () => onDecision(false),
                    child: Text(l10n.hostManageReject),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: ValueKey('approve-request-${request.id}'),
                    onPressed: busy ? null : () => onDecision(true),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.hostManageApprove),
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

class _EmptyPendingRequestsView extends StatelessWidget {
  const _EmptyPendingRequestsView({
    required this.scrollController,
    required this.onRefresh,
  });

  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: palette.muted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.userCheck,
                      size: 36,
                      color: palette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.hostManageNoPending,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.pendingRequestsEmptySub,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
