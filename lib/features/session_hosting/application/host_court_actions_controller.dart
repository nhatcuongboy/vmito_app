// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/court/data/repositories/court_repository_impl.dart';
import 'package:vmito_app/features/court/domain/match_result_draft.dart';
import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/features/court/domain/repositories/court_repository.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session_hosting/application/host_court_actions_state.dart';

/// Every court mutation a host can perform, for one session.
///
/// Separate from `HostSessionManagementController` because court actions are a
/// different resource with different loading semantics — see
/// [HostCourtActionsState] on why busy-ness is per court.
class HostCourtActionsController extends Notifier<HostCourtActionsState> {
  HostCourtActionsController(this.sessionId);

  final String sessionId;

  @override
  HostCourtActionsState build() => const HostCourtActionsState();

  Future<bool> selectPlayers(String courtId, List<PlayerPosition> players) =>
      _run(courtId, (repo) => repo.selectPlayers(courtId, players));

  Future<bool> deselectPlayers(String courtId) =>
      _run(courtId, (repo) => repo.deselectPlayers(courtId));

  Future<bool> startMatch(String courtId) =>
      _run(courtId, (repo) => repo.startMatch(courtId));

  Future<bool> endMatch(String courtId, MatchResultDraft result) =>
      _run(courtId, (repo) => repo.endMatch(courtId, result));

  Future<bool> preSelect(String courtId, List<PlayerPosition> players) =>
      _run(courtId, (repo) => repo.preSelect(courtId, players));

  Future<bool> cancelPreSelect(String courtId) =>
      _run(courtId, (repo) => repo.cancelPreSelect(courtId));

  /// Runs [operation] while marking [courtId] busy, then refetches the session.
  ///
  /// Returns whether it succeeded so the caller can decide what to show. A
  /// failure deliberately does **not** invalidate the session: the server state
  /// did not change, and a refetch would only make the UI flicker.
  Future<bool> _run(
    String courtId,
    Future<void> Function(CourtRepository repo) operation,
  ) async {
    if (state.isBusy(courtId)) return false;
    state = state.copyWith(
      busyCourtIds: {...state.busyCourtIds, courtId},
      error: null,
    );
    try {
      await operation(ref.read(courtRepositoryProvider));
      ref.invalidate(sessionDetailProvider(sessionId));
      return true;
    } on Object catch (error) {
      state = state.copyWith(error: error);
      return false;
    } finally {
      state = state.copyWith(
        busyCourtIds: {...state.busyCourtIds}..remove(courtId),
      );
    }
  }
}

final hostCourtActionsControllerProvider =
    NotifierProvider.family<
      HostCourtActionsController,
      HostCourtActionsState,
      String
    >(HostCourtActionsController.new);
