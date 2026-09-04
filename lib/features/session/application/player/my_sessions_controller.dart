// Family provider implementation types are intentionally inferred; Riverpod
// does not expose their concrete class as public API.
// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';

enum MySessionScope { hosted, joined }

enum MySessionFilter { active, ended, all, pending }

enum MySessionSort {
  dateNearest('startTime', 'asc'),
  dateFurthest('startTime', 'desc'),
  newest('created', 'desc');

  const MySessionSort(this.sortBy, this.sortOrder);

  final String sortBy;
  final String sortOrder;
}

class MySessionsState {
  const MySessionsState({
    this.filter = MySessionFilter.active,
    this.sort = MySessionSort.dateNearest,
    this.search = '',
    this.sessions = const [],
    this.pendingRequests = const [],
    this.page = 1,
    this.totalPages = 1,
    this.pendingCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasLoaded = false,
    this.actingRequestId,
    this.error,
  });

  final MySessionFilter filter;
  final MySessionSort sort;
  final String search;
  final List<Session> sessions;
  final List<PendingJoinRequest> pendingRequests;
  final int page;
  final int totalPages;
  final int pendingCount;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasLoaded;
  final String? actingRequestId;
  final Object? error;

  bool get hasMore => page < totalPages;

  MySessionsState copyWith({
    MySessionFilter? filter,
    MySessionSort? sort,
    String? search,
    List<Session>? sessions,
    List<PendingJoinRequest>? pendingRequests,
    int? page,
    int? totalPages,
    int? pendingCount,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasLoaded,
    String? actingRequestId,
    bool clearActingRequest = false,
    Object? error,
    bool clearError = false,
  }) => MySessionsState(
    filter: filter ?? this.filter,
    sort: sort ?? this.sort,
    search: search ?? this.search,
    sessions: sessions ?? this.sessions,
    pendingRequests: pendingRequests ?? this.pendingRequests,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    pendingCount: pendingCount ?? this.pendingCount,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    actingRequestId: clearActingRequest
        ? null
        : actingRequestId ?? this.actingRequestId,
    error: clearError ? null : error ?? this.error,
  );
}

class MySessionsController extends Notifier<MySessionsState> {
  MySessionsController(this.scope);

  static const pageSize = 20;

  final MySessionScope scope;
  int _requestVersion = 0;

  @override
  MySessionsState build() => const MySessionsState();

  Future<void> loadInitial() async {
    if (!state.hasLoaded && !state.isLoading) await _load(reset: true);
  }

  Future<void> setFilter(MySessionFilter filter) async {
    if (scope == MySessionScope.joined && filter == MySessionFilter.pending) {
      return;
    }
    if (state.filter == filter && state.hasLoaded) return;
    state = state.copyWith(filter: filter, page: 1, clearError: true);
    await _load(reset: true);
  }

  Future<void> setSort(MySessionSort sort) async {
    if (state.sort == sort && state.hasLoaded) return;
    state = state.copyWith(sort: sort, page: 1, clearError: true);
    await _load(reset: true);
  }

  Future<void> setSearch(String search) async {
    final normalized = search.trim();
    if (normalized == state.search) return;
    state = state.copyWith(search: normalized, page: 1, clearError: true);
    await _load(reset: true);
  }

  Future<void> refresh() => _load(reset: true, silent: state.hasLoaded);

  Future<void> refreshIfLoaded() async {
    if (state.hasLoaded) await refresh();
  }

  void restore(MySessionsState snapshot) {
    _requestVersion++;
    state = snapshot;
  }

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
    } on Object catch (error) {
      state = state.copyWith(error: error, clearActingRequest: true);
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await ref.read(sessionRepositoryProvider).cancel(sessionId);
      await refresh();
    } on Object catch (error) {
      state = state.copyWith(error: error);
    }
  }

  Future<void> _load({required bool reset, bool silent = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const MySessionsState(hasLoaded: true);
      return;
    }

    final version = ++_requestVersion;
    final nextPage = reset ? 1 : state.page + 1;
    state = state.copyWith(
      isLoading: reset && !silent,
      isLoadingMore: !reset,
      clearError: true,
    );

    try {
      final repository = ref.read(sessionRepositoryProvider);
      if (scope == MySessionScope.hosted &&
          state.filter == MySessionFilter.pending) {
        final result = await Future.wait<Object>([
          repository.pendingJoinRequests(
            page: nextPage,
            limit: pageSize,
            search: state.search,
          ),
          repository.pendingJoinRequestCount(),
        ]);
        if (version != _requestVersion) return;
        final page = result[0] as Page<PendingJoinRequest>;
        final items = reset
            ? page.items
            : _dedupe(
                [...state.pendingRequests, ...page.items],
                (item) => item.id,
              );
        state = state.copyWith(
          pendingRequests: items,
          pendingCount: result[1] as int,
          page: page.page,
          totalPages: page.totalPages,
          isLoading: false,
          isLoadingMore: false,
          hasLoaded: true,
          clearActingRequest: true,
        );
        return;
      }

      final query = _query(nextPage);
      final page = scope == MySessionScope.hosted
          ? await repository.hostedBy(
              user.id,
              limit: pageSize,
              page: nextPage,
              query: query,
            )
          : await repository.joinedByCurrentUser(query);
      if (version != _requestVersion) return;

      var pendingCount = state.pendingCount;
      if (scope == MySessionScope.hosted) {
        try {
          pendingCount = await repository.pendingJoinRequestCount();
        } on Object {
          // A badge failure should never replace a successfully loaded list.
        }
      }
      if (version != _requestVersion) return;
      final items = reset
          ? page.items
          : _dedupe([...state.sessions, ...page.items], (item) => item.id);
      state = state.copyWith(
        sessions: items,
        pendingCount: pendingCount,
        page: page.page,
        totalPages: page.totalPages,
        isLoading: false,
        isLoadingMore: false,
        hasLoaded: true,
        clearActingRequest: true,
      );
    } on Object catch (error) {
      if (version != _requestVersion) return;
      state = state.copyWith(
        error: error,
        isLoading: false,
        isLoadingMore: false,
        hasLoaded: true,
        clearActingRequest: true,
      );
    }
  }

  SessionListQuery _query(int page) => switch (state.filter) {
    MySessionFilter.active => SessionListQuery(
      page: page,
      search: state.search,
      sortBy: state.sort.sortBy,
      sortOrder: state.sort.sortOrder,
      excludedStatuses: const [
        SessionStatus.finished,
        SessionStatus.cancelled,
      ],
    ),
    MySessionFilter.ended => SessionListQuery(
      page: page,
      search: state.search,
      sortBy: state.sort.sortBy,
      sortOrder: state.sort.sortOrder,
      status: SessionStatus.finished,
    ),
    MySessionFilter.all || MySessionFilter.pending => SessionListQuery(
      page: page,
      search: state.search,
      sortBy: state.sort.sortBy,
      sortOrder: state.sort.sortOrder,
    ),
  };
}

List<T> _dedupe<T>(List<T> items, String Function(T) idOf) {
  final ids = <String>{};
  return items.where((item) => ids.add(idOf(item))).toList(growable: false);
}

final mySessionsControllerProvider =
    NotifierProvider.family<
      MySessionsController,
      MySessionsState,
      MySessionScope
    >(MySessionsController.new);

/// Refreshes the relevant cached scope after registration/notification events.
final mySessionsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final client = ref.watch(socketClientProvider)..connect();
  Timer? debounce;
  final subscription = client.events
      .where((event) => _mySessionRefreshEvents.contains(event.name))
      .listen((event) {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 250), () {
          if (event.name == SessionEvent.registrationRequest) {
            unawaited(
              ref
                  .read(
                    mySessionsControllerProvider(
                      MySessionScope.hosted,
                    ).notifier,
                  )
                  .refreshIfLoaded(),
            );
            return;
          }
          unawaited(
            ref
                .read(
                  mySessionsControllerProvider(MySessionScope.hosted).notifier,
                )
                .refreshIfLoaded(),
          );
          unawaited(
            ref
                .read(
                  mySessionsControllerProvider(MySessionScope.joined).notifier,
                )
                .refreshIfLoaded(),
          );
        });
      });
  ref.onDispose(() {
    debounce?.cancel();
    unawaited(subscription.cancel());
  });
});

const _mySessionRefreshEvents = <String>{
  SessionEvent.registrationRequest,
  SessionEvent.registrationStatusUpdated,
  SessionEvent.notificationReceived,
};
