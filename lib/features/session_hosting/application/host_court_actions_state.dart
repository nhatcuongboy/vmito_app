import 'package:freezed_annotation/freezed_annotation.dart';

part 'host_court_actions_state.freezed.dart';

/// A mutation available from the host's court board.
enum HostCourtAction {
  assign,
  clear,
  start,
  preSelect,
  cancelPreSelect,
  end,
}

/// A failure tied to the court whose host initiated the action.
///
/// Keeping this association prevents every visible court card from showing
/// the same snackbar when one court's mutation fails.
class HostCourtActionFailure {
  const HostCourtActionFailure({required this.courtId, required this.error});

  final String courtId;
  final Object error;
}

/// Which courts have an action in flight, and what last went wrong.
///
/// Busy-ness is tracked **per court**, not per screen: a host ending a match on
/// court 3 must still be able to read — and act on — court 1. The web tracks
/// the same thing with `loadingStartMatchCourtId` and friends.
@freezed
abstract class HostCourtActionsState with _$HostCourtActionsState {
  const factory HostCourtActionsState({
    @Default(<String, HostCourtAction>{})
    Map<String, HostCourtAction> activeActionsByCourtId,

    /// The last failure, kept only so its owning court card can render it.
    /// Cleared when any action starts.
    HostCourtActionFailure? failure,
  }) = _HostCourtActionsState;

  const HostCourtActionsState._();

  bool isBusy(String courtId) => activeActionsByCourtId.containsKey(courtId);

  HostCourtAction? activeActionFor(String courtId) =>
      activeActionsByCourtId[courtId];
}
