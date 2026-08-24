import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';

class MyJoinRequestsState {
  const MyJoinRequestsState({
    this.requests = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasLoaded = false,
    this.withdrawingSessionId,
    this.error,
  });

  final List<MyJoinRequest> requests;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasLoaded;
  final String? withdrawingSessionId;
  final Object? error;

  bool get hasMore => page < totalPages;

  MyJoinRequestsState copyWith({
    List<MyJoinRequest>? requests,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasLoaded,
    String? withdrawingSessionId,
    bool clearWithdrawingSessionId = false,
    Object? error,
    bool clearError = false,
  }) => MyJoinRequestsState(
    requests: requests ?? this.requests,
    total: total ?? this.total,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    withdrawingSessionId: clearWithdrawingSessionId
        ? null
        : withdrawingSessionId ?? this.withdrawingSessionId,
    error: clearError ? null : error ?? this.error,
  );
}

class MyJoinRequestsController extends Notifier<MyJoinRequestsState> {
  static const pageSize = 20;

  int _requestVersion = 0;

  @override
  MyJoinRequestsState build() => const MyJoinRequestsState();

  Future<void> loadInitial() async {
    if (!state.hasLoaded && !state.isLoading) await _load(page: 1);
  }

  Future<void> refresh() => _load(page: 1, silent: state.hasLoaded);

  Future<void> nextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await _load(page: state.page + 1);
  }

  Future<void> previousPage() async {
    if (state.isLoading || state.isLoadingMore || state.page <= 1) return;
    await _load(page: state.page - 1);
  }

  Future<bool> withdraw(MyJoinRequest request) async {
    if (state.withdrawingSessionId != null || !request.hasPending) {
      return false;
    }
    state = state.copyWith(
      withdrawingSessionId: request.session.id,
      clearError: true,
    );
    try {
      await ref
          .read(registrationRepositoryProvider)
          .withdrawMyJoinRequest(request.session.id);
      await _load(page: state.page, silent: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        error: error,
        clearWithdrawingSessionId: true,
      );
      return false;
    }
  }

  Future<void> _load({required int page, bool silent = false}) async {
    final version = ++_requestVersion;
    state = state.copyWith(
      isLoading: page == 1 && !silent,
      isLoadingMore: page > 1 || silent,
      clearError: true,
    );

    try {
      final result = await ref
          .read(registrationRepositoryProvider)
          .myJoinRequests(
            page: page,
            limit: pageSize,
          );
      if (version != _requestVersion) return;
      state = state.copyWith(
        requests: result.items,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        isLoading: false,
        isLoadingMore: false,
        hasLoaded: true,
        clearWithdrawingSessionId: true,
      );
    } on Object catch (error) {
      if (version != _requestVersion) return;
      state = state.copyWith(
        error: error,
        isLoading: false,
        isLoadingMore: false,
        hasLoaded: true,
        clearWithdrawingSessionId: true,
      );
    }
  }
}

final myJoinRequestsControllerProvider =
    NotifierProvider<MyJoinRequestsController, MyJoinRequestsState>(
      MyJoinRequestsController.new,
    );

/// Keeps the submitted-request badge and drawer current after host decisions.
final Provider<void> myJoinRequestsRealtimeProvider =
    Provider.autoDispose<void>((ref) {
      final client = ref.watch(socketClientProvider)..connect();
      Timer? debounce;
      final subscription = client.events
          .where((event) => _myJoinRequestRefreshEvents.contains(event.name))
          .listen((_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 250), () {
              unawaited(
                ref.read(myJoinRequestsControllerProvider.notifier).refresh(),
              );
            });
          });
      ref.onDispose(() {
        debounce?.cancel();
        unawaited(subscription.cancel());
      });
    });

const _myJoinRequestRefreshEvents = <String>{
  SessionEvent.registrationStatusUpdated,
  SessionEvent.notificationReceived,
};
