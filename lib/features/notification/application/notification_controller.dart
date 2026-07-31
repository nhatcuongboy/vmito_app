import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/notification/data/notification_service.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';

class NotificationState {
  const NotificationState({
    this.items = const [],
    this.unreadCount = 0,
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final ApiException? error;

  bool get hasMore => page < totalPages;
}

class NotificationController extends Notifier<NotificationState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  NotificationState build() {
    final socket = ref.watch(socketClientProvider)..connect();
    _subscription = socket.on(SessionEvent.notificationReceived).listen(_add);
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return const NotificationState();
  }

  NotificationService get _service => ref.read(notificationServiceProvider);

  Future<void> load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    state = NotificationState(
      items: state.items,
      unreadCount: state.unreadCount,
      isLoading: true,
    );
    try {
      final pageFuture = _service.list();
      final unreadFuture = _service.unreadCount();
      final page = await pageFuture;
      final unreadCount = await unreadFuture;
      state = NotificationState(
        items: page.items,
        unreadCount: unreadCount,
        page: page.page,
        totalPages: page.totalPages,
      );
    } on ApiException catch (error) {
      state = NotificationState(
        items: state.items,
        unreadCount: state.unreadCount,
        error: error,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    state = NotificationState(
      items: state.items,
      unreadCount: state.unreadCount,
      page: state.page,
      totalPages: state.totalPages,
      isLoadingMore: true,
    );
    try {
      final page = await _service.list(page: state.page + 1);
      final ids = state.items.map((item) => item.id).toSet();
      state = NotificationState(
        items: [
          ...state.items,
          ...page.items.where((item) => ids.add(item.id)),
        ],
        unreadCount: state.unreadCount,
        page: page.page,
        totalPages: page.totalPages,
      );
    } on ApiException catch (error) {
      state = NotificationState(
        items: state.items,
        unreadCount: state.unreadCount,
        page: state.page,
        totalPages: state.totalPages,
        error: error,
      );
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await _service.markRead(notification.id);
    } on ApiException catch (error) {
      state = NotificationState(
        items: state.items,
        unreadCount: state.unreadCount,
        page: state.page,
        totalPages: state.totalPages,
        error: error,
      );
      return;
    }
    state = NotificationState(
      items: [
        for (final item in state.items)
          if (item.id == notification.id) item.markRead() else item,
      ],
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
      page: state.page,
      totalPages: state.totalPages,
    );
  }

  Future<void> markAllRead() async {
    try {
      await _service.markAllRead();
    } on ApiException catch (error) {
      state = NotificationState(
        items: state.items,
        unreadCount: state.unreadCount,
        page: state.page,
        totalPages: state.totalPages,
        error: error,
      );
      return;
    }
    state = NotificationState(
      items: state.items.map((item) => item.markRead()).toList(),
      page: state.page,
      totalPages: state.totalPages,
    );
  }

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
      state = NotificationState(
        items: [notification, ...state.items],
        unreadCount: state.unreadCount + (notification.isRead ? 0 : 1),
        page: state.page,
        totalPages: state.totalPages,
      );
    } on Object {
      // A malformed socket hint must not take down the notification center.
    }
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
