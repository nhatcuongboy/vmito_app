import 'package:freezed_annotation/freezed_annotation.dart';

part 'host_court_actions_state.freezed.dart';

/// Which courts have an action in flight, and what last went wrong.
///
/// Busy-ness is tracked **per court**, not per screen: a host ending a match on
/// court 3 must still be able to read — and act on — court 1. The web tracks
/// the same thing with `loadingStartMatchCourtId` and friends.
@freezed
abstract class HostCourtActionsState with _$HostCourtActionsState {
  const factory HostCourtActionsState({
    @Default(<String>{}) Set<String> busyCourtIds,

    /// The last failure, kept only so a call site can render its message.
    /// Cleared when any action starts.
    Object? error,
  }) = _HostCourtActionsState;

  const HostCourtActionsState._();

  bool isBusy(String courtId) => busyCourtIds.contains(courtId);
}
