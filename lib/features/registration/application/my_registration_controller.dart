// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';
import 'package:vmito_app/features/registration/domain/registration_player_draft.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// What a withdraw attempt actually achieved.
///
/// Withdrawing is N independent deletes, and some of them legitimately fail —
/// a guest row 403s and a player on court 400s. Reporting a bare "done" would
/// tell the user their slot is gone when it is not.
class WithdrawOutcome {
  const WithdrawOutcome({required this.withdrawn, required this.failed});

  final int withdrawn;
  final int failed;

  bool get isCompleteSuccess => failed == 0;
}

/// The caller's registration for one session.
///
/// Drives the detail screen's bottom bar and the "my registration" sheet.
class MyRegistrationController extends AsyncNotifier<List<SessionPlayer>> {
  MyRegistrationController(this.sessionId);

  final String sessionId;

  @override
  Future<List<SessionPlayer>> build() async {
    // The endpoint needs a token. Signed out there is nothing to read, and a
    // guaranteed 401 would surface as an error state on the bar.
    if (!ref.watch(isSignedInProvider)) return const [];
    return ref.watch(registrationRepositoryProvider).myPlayers(sessionId);
  }

  /// Submits the form. Throws on failure so the sheet can stay open and show
  /// the backend's message.
  Future<void> register(List<RegistrationPlayerDraft> drafts) async {
    final myUserId = ref.read(currentUserProvider)?.id;
    await ref.read(registrationRepositoryProvider).register(
      sessionId,
      [for (final draft in drafts) draft.toRegisterJson(myUserId)],
    );
    _refresh();
  }

  /// Deletes every pending row, one at a time.
  ///
  /// Sequential rather than concurrent so a failure on one row does not
  /// abandon the rest, and so the caller learns how many actually went.
  /// Approved and rejected rows are left alone — matching the web app, a
  /// partially approved registration keeps its approved slots.
  Future<WithdrawOutcome> withdrawPending() async {
    final pending = (state.value ?? const <SessionPlayer>[])
        .where((player) => player.isPendingApproval)
        .toList();

    final repository = ref.read(registrationRepositoryProvider);
    var withdrawn = 0;
    var failed = 0;
    for (final player in pending) {
      try {
        await repository.withdraw(player.id);
        withdrawn++;
      } on Object {
        failed++;
      }
    }

    _refresh();
    return WithdrawOutcome(withdrawn: withdrawn, failed: failed);
  }

  /// The session's own record changes too — `_count.players` drives the
  /// remaining-slots badge and the full/not-full state of the register button.
  void _refresh() {
    ref
      ..invalidateSelf()
      ..invalidate(sessionDetailProvider(sessionId));
  }
}

final myRegistrationProvider = AsyncNotifierProvider.autoDispose
    .family<MyRegistrationController, List<SessionPlayer>, String>(
      MyRegistrationController.new,
    );

/// The single status the bottom bar renders from.
///
/// Reads the **first** row, as the web app does: rows come back oldest-first,
/// so this is the earliest slot. With mixed statuses across slots it does not
/// aggregate — kept deliberately identical to web rather than "fixed" here,
/// so the two clients cannot disagree about what a registration looks like.
final myRegistrationStatusProvider =
    Provider.family<RegistrationStatus?, String>(
      (ref, sessionId) {
        final players = ref.watch(myRegistrationProvider(sessionId)).value;
        if (players == null || players.isEmpty) return null;
        return players.first.registrationStatus;
      },
    );

/// Registration statuses indexed by session for public session cards.
///
/// The public-session endpoint intentionally omits player rows, so browse
/// screens load this user-specific projection separately.
final myRegistrationStatusesProvider =
    FutureProvider.autoDispose<Map<String, RegistrationStatus>>((ref) async {
      if (!ref.watch(isSignedInProvider)) return const {};

      final statuses = <String, RegistrationStatus>{};
      var page = 1;
      var totalPages = 1;
      final repository = ref.watch(registrationRepositoryProvider);

      while (page <= totalPages) {
        final result = await repository.myJoinRequests(page: page, limit: 100);
        for (final request in result.items) {
          if (request.players.isNotEmpty) {
            statuses[request.session.id] =
                request.players.first.registrationStatus;
          }
        }
        page = result.page + 1;
        totalPages = result.totalPages;
      }

      return statuses;
    });
