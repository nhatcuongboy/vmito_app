// Provider declarations intentionally use inferred family types.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/form/match_update_draft.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';

class HostMatchActionsState {
  const HostMatchActionsState({
    this.busyMatchIds = const {},
    this.error,
  });

  final Set<String> busyMatchIds;
  final Object? error;

  bool isBusy(String matchId) => busyMatchIds.contains(matchId);

  HostMatchActionsState copyWith({
    Set<String>? busyMatchIds,
    Object? error,
    bool clearError = false,
  }) => HostMatchActionsState(
    busyMatchIds: busyMatchIds ?? this.busyMatchIds,
    error: clearError ? null : error ?? this.error,
  );
}

class HostMatchActionsController extends Notifier<HostMatchActionsState> {
  HostMatchActionsController(this.sessionId);

  final String sessionId;

  @override
  HostMatchActionsState build() => const HostMatchActionsState();

  Future<bool> update(String matchId, MatchUpdateDraft draft) => _run(
    matchId,
    () => ref.read(sessionRepositoryProvider).updateMatch(matchId, draft),
  );

  Future<bool> delete(String matchId) => _run(
    matchId,
    () => ref.read(sessionRepositoryProvider).deleteMatch(matchId),
  );

  Future<bool> _run(String matchId, Future<void> Function() operation) async {
    if (state.isBusy(matchId)) return false;
    state = state.copyWith(
      busyMatchIds: {...state.busyMatchIds, matchId},
      clearError: true,
    );
    try {
      await operation();
      ref
        ..invalidate(matchHistoryProvider(sessionId))
        ..invalidate(sessionDetailProvider(sessionId))
        ..invalidate(playerStatisticsProvider(sessionId));
      return true;
    } on Object catch (error) {
      state = state.copyWith(error: error);
      return false;
    } finally {
      state = state.copyWith(
        busyMatchIds: {...state.busyMatchIds}..remove(matchId),
      );
    }
  }
}

final hostMatchActionsControllerProvider =
    NotifierProvider.family<
      HostMatchActionsController,
      HostMatchActionsState,
      String
    >(HostMatchActionsController.new);
