import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/social/data/newsfeed_badge_service.dart';

class NewsfeedBadgeState {
  const NewsfeedBadgeState({
    this.count = 0,
    this.isLoading = false,
    this.error,
  });

  final int count;
  final bool isLoading;
  final Object? error;

  NewsfeedBadgeState copyWith({
    int? count,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) => NewsfeedBadgeState(
    count: count ?? this.count,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
  );
}

/// Owns request ordering for the feed badge.
///
/// Socket messages are hints: they invalidate any active GET and request a
/// fresh server count instead of incrementing client state.
class NewsfeedBadgeController extends Notifier<NewsfeedBadgeState> {
  static const _maxFetchAttempts = 3;

  int _generation = 0;
  int _version = 0;
  Future<void>? _fetchInFlight;
  Future<void>? _markInFlight;
  Object? _activeFetchId;
  Object? _activeMarkId;

  @override
  NewsfeedBadgeState build() => const NewsfeedBadgeState();

  NewsfeedBadgeService get _service => ref.read(newsfeedBadgeServiceProvider);

  Future<void> fetchCount() {
    final active = _fetchInFlight;
    if (active != null) return active;

    final fetchGeneration = _generation;
    final requestId = Object();
    var requestVersion = _version;
    _activeFetchId = requestId;

    final request = () async {
      state = state.copyWith(isLoading: true, clearError: true);
      try {
        for (var attempt = 0; attempt < _maxFetchAttempts; attempt++) {
          requestVersion = _version;
          final count = await _service.unreadCount();

          if (fetchGeneration != _generation) return;
          if (requestVersion == _version) {
            state = state.copyWith(count: count, clearError: true);
            return;
          }

          final mark = _markInFlight;
          if (mark != null) await mark;
        }
      } on Object catch (error) {
        if (fetchGeneration == _generation &&
            requestVersion == _version &&
            identical(_activeFetchId, requestId)) {
          state = state.copyWith(error: error);
        }
      } finally {
        if (identical(_activeFetchId, requestId)) {
          _activeFetchId = null;
          _fetchInFlight = null;
          state = state.copyWith(isLoading: false);
        }
      }
    }();

    _fetchInFlight = request;
    return request;
  }

  Future<void> markAsRead() {
    final active = _markInFlight;
    if (active != null) return active;

    _version++;
    final markGeneration = _generation;
    final markVersion = _version;
    final requestId = Object();
    _activeMarkId = requestId;
    state = state.copyWith(count: 0, clearError: true);

    final request = () async {
      var shouldRevalidate = false;
      try {
        await _service.markAsRead();
      } on Object catch (error) {
        shouldRevalidate = true;
        if (markGeneration == _generation && markVersion == _version) {
          state = state.copyWith(error: error);
        }
      } finally {
        if (identical(_activeMarkId, requestId)) {
          _activeMarkId = null;
          _markInFlight = null;
        }
        if (shouldRevalidate &&
            markGeneration == _generation &&
            markVersion == _version) {
          unawaited(fetchCount());
        }
      }
    }();

    _markInFlight = request;
    return request;
  }

  void handleRealtimeHint() {
    _version++;
    unawaited(fetchCount());
  }

  void reset() {
    _generation++;
    _version++;
    _fetchInFlight = null;
    _markInFlight = null;
    _activeFetchId = null;
    _activeMarkId = null;
    state = const NewsfeedBadgeState();
  }
}

final newsfeedBadgeControllerProvider =
    NotifierProvider<NewsfeedBadgeController, NewsfeedBadgeState>(
      NewsfeedBadgeController.new,
    );
