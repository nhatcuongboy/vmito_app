import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/notification/data/notification_service.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/features/notification/domain/notification_panel_item.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue_approval_request.dart';

const _unset = Object();

class NotificationState {
  const NotificationState({
    this.items = const [],
    this.sessionRequests = const [],
    this.clubRequests = const [],
    this.venueRequests = const [],
    this.unreadCount = 0,
    this.sessionPendingCount = 0,
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isMarkingAll = false,
    this.hasLoaded = false,
    this.hasSuccessfulLoad = false,
    this.actingSessionGroupKey,
    this.actingClubRequestId,
    this.deletingNotificationId,
    this.error,
  });

  final List<AppNotification> items;
  final List<PendingJoinRequest> sessionRequests;
  final List<ClubJoinRequest> clubRequests;
  final List<VenueApprovalRequest> venueRequests;
  final int unreadCount;
  final int sessionPendingCount;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isMarkingAll;
  final bool hasLoaded;
  final bool hasSuccessfulLoad;
  final String? actingSessionGroupKey;
  final String? actingClubRequestId;
  final String? deletingNotificationId;
  final Object? error;

  bool get hasMore => page < totalPages;
  int get pendingApprovalCount =>
      sessionPendingCount + clubRequests.length + venueRequests.length;
  int get totalBadgeCount => unreadCount + pendingApprovalCount;
  List<NotificationPanelItem> get panelItems => buildNotificationPanelItems(
    notifications: items,
    sessionRequests: sessionRequests,
    clubRequests: clubRequests,
    venueRequests: venueRequests,
  );

  NotificationState copyWith({
    List<AppNotification>? items,
    List<PendingJoinRequest>? sessionRequests,
    List<ClubJoinRequest>? clubRequests,
    List<VenueApprovalRequest>? venueRequests,
    int? unreadCount,
    int? sessionPendingCount,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isMarkingAll,
    bool? hasLoaded,
    bool? hasSuccessfulLoad,
    Object? actingSessionGroupKey = _unset,
    Object? actingClubRequestId = _unset,
    Object? deletingNotificationId = _unset,
    Object? error = _unset,
  }) => NotificationState(
    items: items ?? this.items,
    sessionRequests: sessionRequests ?? this.sessionRequests,
    clubRequests: clubRequests ?? this.clubRequests,
    venueRequests: venueRequests ?? this.venueRequests,
    unreadCount: unreadCount ?? this.unreadCount,
    sessionPendingCount: sessionPendingCount ?? this.sessionPendingCount,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isMarkingAll: isMarkingAll ?? this.isMarkingAll,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    hasSuccessfulLoad: hasSuccessfulLoad ?? this.hasSuccessfulLoad,
    actingSessionGroupKey: identical(actingSessionGroupKey, _unset)
        ? this.actingSessionGroupKey
        : actingSessionGroupKey as String?,
    actingClubRequestId: identical(actingClubRequestId, _unset)
        ? this.actingClubRequestId
        : actingClubRequestId as String?,
    deletingNotificationId: identical(deletingNotificationId, _unset)
        ? this.deletingNotificationId
        : deletingNotificationId as String?,
    error: identical(error, _unset) ? this.error : error,
  );
}

class NotificationController extends Notifier<NotificationState> {
  static const pageSize = 20;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  NotificationState build() {
    final socket = ref.watch(socketClientProvider)..connect();
    _subscription = socket.on(SessionEvent.notificationReceived).listen(_add);
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return const NotificationState();
  }

  NotificationService get _service => ref.read(notificationServiceProvider);

  Future<bool> _canManageApprovals() async {
    try {
      return await ref.read(hostFeatureAccessProvider.future);
    } on Object {
      return false;
    }
  }

  Future<void> refreshSummary() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final canManage = await _canManageApprovals();
    final sessionCountFuture = canManage
        ? _capture(
            ref.read(sessionRepositoryProvider).pendingJoinRequestCount(),
          )
        : Future.value(const _Captured<int>.data(0));
    final clubsFuture = canManage
        ? _capture(
            ref
                .read(socialServiceProvider)
                .managedClubJoinRequests(admin: user.isAdmin),
          )
        : Future.value(const _Captured<List<ClubJoinRequest>>.data([]));
    final venuesFuture = user.isAdmin
        ? _capture(ref.read(venueServiceProvider).pendingAdminRequests())
        : Future.value(
            const _Captured<List<VenueApprovalRequest>>.data([]),
          );
    final results = await Future.wait<Object>([
      _capture(_service.unreadCount()),
      sessionCountFuture,
      clubsFuture,
      venuesFuture,
    ]);
    final unread = results[0] as _Captured<int>;
    final sessionCount = results[1] as _Captured<int>;
    final clubs = results[2] as _Captured<List<ClubJoinRequest>>;
    final venues = results[3] as _Captured<List<VenueApprovalRequest>>;
    state = state.copyWith(
      unreadCount: unread.value ?? state.unreadCount,
      sessionPendingCount: sessionCount.value ?? state.sessionPendingCount,
      clubRequests: clubs.value == null
          ? state.clubRequests
          : _pendingClubRequests(clubs.value!),
      venueRequests: venues.value ?? state.venueRequests,
      error: unread.error ?? sessionCount.error ?? clubs.error ?? venues.error,
    );
  }

  Future<void> refreshUnreadCount() => refreshSummary();

  Future<void> load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    state = state.copyWith(isLoading: true, error: null);
    final canManage = await _canManageApprovals();
    const emptySessionPage = Page<PendingJoinRequest>(
      items: [],
      total: 0,
      page: 1,
      limit: pageSize,
      totalPages: 1,
    );
    final sessionsFuture = canManage
        ? _capture(
            ref
                .read(sessionRepositoryProvider)
                .pendingJoinRequests(page: 1, limit: pageSize),
          )
        : Future.value(const _Captured.data(emptySessionPage));
    final sessionCountFuture = canManage
        ? _capture(
            ref.read(sessionRepositoryProvider).pendingJoinRequestCount(),
          )
        : Future.value(const _Captured<int>.data(0));
    final clubsFuture = canManage
        ? _capture(
            ref
                .read(socialServiceProvider)
                .managedClubJoinRequests(admin: user.isAdmin),
          )
        : Future.value(const _Captured<List<ClubJoinRequest>>.data([]));
    final venuesFuture = user.isAdmin
        ? _capture(ref.read(venueServiceProvider).pendingAdminRequests())
        : Future.value(
            const _Captured<List<VenueApprovalRequest>>.data([]),
          );
    final results = await Future.wait<Object>([
      _capture(_service.list()),
      _capture(_service.unreadCount()),
      sessionsFuture,
      sessionCountFuture,
      clubsFuture,
      venuesFuture,
    ]);

    final notifications = results[0] as _Captured<Page<AppNotification>>;
    final unread = results[1] as _Captured<int>;
    final sessions = results[2] as _Captured<Page<PendingJoinRequest>>;
    final sessionCount = results[3] as _Captured<int>;
    final clubs = results[4] as _Captured<List<ClubJoinRequest>>;
    final venues = results[5] as _Captured<List<VenueApprovalRequest>>;
    final notificationPage = notifications.value;
    final sessionPage = sessions.value;
    final hasSuccessfulPanelSource =
        notificationPage != null ||
        (canManage && (sessionPage != null || clubs.value != null)) ||
        (user.isAdmin && venues.value != null);

    state = state.copyWith(
      items: notificationPage?.items ?? state.items,
      unreadCount: unread.value ?? state.unreadCount,
      sessionRequests: sessionPage?.items ?? state.sessionRequests,
      sessionPendingCount: sessionCount.value ?? state.sessionPendingCount,
      clubRequests: clubs.value == null
          ? state.clubRequests
          : _pendingClubRequests(clubs.value!),
      venueRequests: venues.value ?? state.venueRequests,
      page: notificationPage?.page ?? state.page,
      totalPages: notificationPage?.totalPages ?? state.totalPages,
      isLoading: false,
      hasLoaded: true,
      hasSuccessfulLoad: hasSuccessfulPanelSource,
      error:
          notifications.error ??
          unread.error ??
          sessions.error ??
          sessionCount.error ??
          clubs.error ??
          venues.error,
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true, error: null);
    final result = await _capture(
      _service.list(page: state.page + 1),
    );
    final page = result.value;
    if (page == null) {
      state = state.copyWith(isLoadingMore: false, error: result.error);
      return;
    }
    final ids = state.items.map((item) => item.id).toSet();
    state = state.copyWith(
      items: [
        ...state.items,
        ...page.items.where((item) => ids.add(item.id)),
      ],
      page: page.page,
      totalPages: page.totalPages,
      isLoadingMore: false,
    );
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final result = await _capture(_service.markRead(notification.id));
    if (result.error != null) {
      state = state.copyWith(error: result.error);
      return;
    }
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == notification.id) item.markRead() else item,
      ],
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0 || state.isMarkingAll) return;
    state = state.copyWith(isMarkingAll: true, error: null);
    final result = await _capture(_service.markAllRead());
    if (result.error != null) {
      state = state.copyWith(isMarkingAll: false, error: result.error);
      return;
    }
    state = state.copyWith(
      items: state.items.map((item) => item.markRead()).toList(),
      unreadCount: 0,
      isMarkingAll: false,
    );
  }

  Future<void> delete(String id) async {
    if (state.deletingNotificationId != null) return;
    final notification = state.items.where((item) => item.id == id).firstOrNull;
    if (notification == null) return;
    state = state.copyWith(deletingNotificationId: id, error: null);
    final result = await _capture(_service.delete(id));
    if (result.error != null) {
      state = state.copyWith(
        deletingNotificationId: null,
        error: result.error,
      );
      return;
    }
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
      unreadCount: notification.isRead
          ? state.unreadCount
          : (state.unreadCount > 0 ? state.unreadCount - 1 : 0),
      deletingNotificationId: null,
    );
  }

  Future<bool> decideSessionRequest(
    SessionApprovalItem group, {
    required bool approved,
  }) async {
    if (state.actingSessionGroupKey != null) return false;
    final key = group.request.groupKey;
    final ids = group.slots.map((item) => item.id).toList(growable: false);
    state = state.copyWith(actingSessionGroupKey: key, error: null);
    final result = await _capture(
      ref
          .read(sessionRepositoryProvider)
          .updatePendingRegistrations(ids, approved: approved),
    );
    if (result.error != null) {
      state = state.copyWith(actingSessionGroupKey: null, error: result.error);
      return false;
    }
    final idSet = ids.toSet();
    state = state.copyWith(
      sessionRequests: state.sessionRequests
          .where((item) => !idSet.contains(item.id))
          .toList(),
      sessionPendingCount: (state.sessionPendingCount - ids.length).clamp(
        0,
        1 << 31,
      ),
      actingSessionGroupKey: null,
    );
    return true;
  }

  Future<bool> decideClubRequest(
    ClubJoinRequest request, {
    required bool approved,
  }) async {
    if (state.actingClubRequestId != null) return false;
    state = state.copyWith(actingClubRequestId: request.id, error: null);
    final service = ref.read(socialServiceProvider);
    final result = await _capture(
      approved
          ? service.approveClubJoinRequest(request.clubId, request.id)
          : service.rejectClubJoinRequest(request.clubId, request.id),
    );
    if (result.error != null) {
      state = state.copyWith(actingClubRequestId: null, error: result.error);
      return false;
    }
    state = state.copyWith(
      clubRequests: state.clubRequests
          .where((item) => item.id != request.id)
          .toList(),
      actingClubRequestId: null,
    );
    ref.invalidate(incomingClubRequestsProvider);
    return true;
  }

  void clearError() => state = state.copyWith(error: null);

  void _add(Map<String, dynamic> payload) {
    final raw = payload['notification'] is Map
        ? Map<String, dynamic>.from(payload['notification'] as Map)
        : payload;
    try {
      final notification = AppNotification.fromJson(raw);
      final user = ref.read(currentUserProvider);
      if (notification.userId != user?.id ||
          state.items.any((item) => item.id == notification.id)) {
        return;
      }
      state = state.copyWith(
        items: [notification, ...state.items],
        unreadCount: state.unreadCount + (notification.isRead ? 0 : 1),
      );
    } on Object {
      // A malformed socket hint must not take down the notification center.
    }
  }
}

class _Captured<T> {
  const _Captured.data(this.value) : error = null;
  const _Captured.error(this.error) : value = null;

  final T? value;
  final Object? error;
}

Future<_Captured<T>> _capture<T>(Future<T> future) async {
  try {
    return _Captured.data(await future);
  } on Object catch (error) {
    return _Captured.error(error);
  }
}

List<ClubJoinRequest> _pendingClubRequests(List<ClubJoinRequest> requests) =>
    requests
        .where((request) => request.status == 'PENDING')
        .toList(growable: false);

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
