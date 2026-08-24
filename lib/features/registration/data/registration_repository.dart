import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// Self-service registration: the player's own slots in a session.
///
/// Separate from `SessionRepository`, which is about the session resource
/// itself. These three calls are all scoped to "me", and two of them are the
/// only writes a non-host player can make against a session's roster.
class RegistrationRepository {
  const RegistrationRepository(this._client);

  final ApiClient _client;

  /// Requests submitted by the current user, grouped by session.
  Future<Page<MyJoinRequest>> myJoinRequests({
    required int page,
    required int limit,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.myJoinRequests,
      queryParameters: {'page': page, 'limit': limit},
    );
    return unwrapPage(response.data, MyJoinRequest.fromJson);
  }

  /// Withdraws every pending registration row owned by the current user for
  /// [sessionId]. Approved/rejected rows are intentionally left untouched by
  /// the backend contract.
  Future<void> withdrawMyJoinRequest(String sessionId) async {
    await _client.delete<void>(
      ApiEndpoints.withdrawMyJoinRequest(sessionId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  /// The caller's rows for [sessionId], oldest first, including guests they
  /// registered. Empty means not registered.
  ///
  /// The response is a **projection** — nine fields, not a full player — but
  /// every one of them is optional or defaulted on [SessionPlayer], so it
  /// parses without a parallel model.
  Future<List<SessionPlayer>> myPlayers(String sessionId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.sessionMyPlayers(sessionId),
    );
    return unwrapList(response.data, SessionPlayer.fromJson);
  }

  /// Registers one or more rows in a single call.
  ///
  /// [players] must already be wire-shaped — see
  /// `RegistrationPlayerDraft.toRegisterJson`. The body wraps them under a
  /// `players` key; the sibling `POST /sessions/:id/players` does *not*, so
  /// the two are easy to confuse.
  ///
  /// `skipGlobalError` because the sheet stays open on failure and shows the
  /// backend's message inline, matching the web modal.
  Future<void> register(
    String sessionId,
    List<Map<String, dynamic>> players,
  ) async {
    await _client.post<dynamic>(
      ApiEndpoints.sessionRegister(sessionId),
      data: {'players': players},
      options: apiOptions(skipGlobalError: true),
    );
  }

  /// Withdraws one row. There is no bulk or dedicated withdraw endpoint —
  /// withdrawing a multi-slot registration means calling this per row.
  ///
  /// Throws on a row the caller may not delete: the backend's guard checks
  /// `userId` only, so a **guest row returns 403** even though the caller
  /// created it, and a player who is currently on court returns 400.
  Future<void> withdraw(String playerId) async {
    await _client.delete<dynamic>(
      ApiEndpoints.player(playerId),
      options: apiOptions(skipGlobalError: true),
    );
  }
}

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => RegistrationRepository(ref.watch(apiClientProvider)),
);
