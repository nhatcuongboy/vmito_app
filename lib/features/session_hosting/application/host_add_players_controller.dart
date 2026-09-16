// Provider declarations intentionally use inferred family types.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/roster/data/roster_service.dart';
import 'package:vmito_app/features/roster/domain/host_recent_player.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';

class HostAddPlayersState {
  const HostAddPlayersState({
    this.users = const [],
    this.recentPlayers = const [],
    this.clubs = const [],
    this.feesByClubId = const {},
    this.monthlyMemberUserIds = const {},
    this.loadingUsers = false,
    this.loadingRecentPlayers = false,
    this.loadingClubData = false,
    this.submitting = false,
    this.error,
  });

  final List<HostPlayerUserOption> users;
  final List<HostRecentPlayer> recentPlayers;
  final List<ClubSummary> clubs;
  final Map<String, ClubFeeConfig> feesByClubId;
  final Set<String> monthlyMemberUserIds;
  final bool loadingUsers;
  final bool loadingRecentPlayers;
  final bool loadingClubData;
  final bool submitting;
  final Object? error;

  HostAddPlayersState copyWith({
    List<HostPlayerUserOption>? users,
    List<HostRecentPlayer>? recentPlayers,
    List<ClubSummary>? clubs,
    Map<String, ClubFeeConfig>? feesByClubId,
    Set<String>? monthlyMemberUserIds,
    bool? loadingUsers,
    bool? loadingRecentPlayers,
    bool? loadingClubData,
    bool? submitting,
    Object? error,
    bool clearError = false,
  }) => HostAddPlayersState(
    users: users ?? this.users,
    recentPlayers: recentPlayers ?? this.recentPlayers,
    clubs: clubs ?? this.clubs,
    feesByClubId: feesByClubId ?? this.feesByClubId,
    monthlyMemberUserIds: monthlyMemberUserIds ?? this.monthlyMemberUserIds,
    loadingUsers: loadingUsers ?? this.loadingUsers,
    loadingRecentPlayers: loadingRecentPlayers ?? this.loadingRecentPlayers,
    loadingClubData: loadingClubData ?? this.loadingClubData,
    submitting: submitting ?? this.submitting,
    error: clearError ? null : error ?? this.error,
  );
}

class HostAddPlayersController extends Notifier<HostAddPlayersState> {
  HostAddPlayersController(this.sessionId);

  final String sessionId;
  int _searchGeneration = 0;
  int _recentGeneration = 0;
  bool _initialized = false;

  @override
  HostAddPlayersState build() => const HostAddPlayersState();

  Future<void> initialize(Session session) async {
    if (_initialized) return;
    _initialized = true;
    state = state.copyWith(loadingClubData: true, clearError: true);
    await searchUsers('');
    try {
      final clubs = await ref.read(managedClubsProvider.future);
      final date = session.startTime ?? session.scheduledStartTime;
      if (date == null) {
        state = state.copyWith(clubs: clubs, loadingClubData: false);
        return;
      }
      final service = ref.read(socialServiceProvider);
      final feeEntries = await Future.wait(
        clubs.map((club) async {
          final fee = await service.clubFeeForMonth(
            club.id,
            date.year,
            date.month,
          );
          return MapEntry(club.id, fee);
        }),
      );
      final fees = <String, ClubFeeConfig>{
        for (final entry in feeEntries)
          if (entry.value?.hasPerSessionFee ?? false) entry.key: entry.value!,
      };
      var memberIds = <String>{};
      final sessionClubId = session.clubId;
      if (sessionClubId != null && sessionClubId.isNotEmpty) {
        try {
          final members = await service.clubMonthlyMembers(
            sessionClubId,
            date.year,
            date.month,
          );
          memberIds = members.map((member) => member.userId).toSet();
        } on Object {
          memberIds = <String>{};
        }
      }
      state = state.copyWith(
        clubs: clubs.where((club) => fees.containsKey(club.id)).toList(),
        feesByClubId: fees,
        monthlyMemberUserIds: memberIds,
        loadingClubData: false,
      );
    } on Object catch (error) {
      state = state.copyWith(loadingClubData: false, error: error);
    }
  }

  Future<void> searchUsers(String query) async {
    final generation = ++_searchGeneration;
    state = state.copyWith(loadingUsers: true, clearError: true);
    try {
      final users = await ref
          .read(sessionRepositoryProvider)
          .searchUsers(query);
      if (generation != _searchGeneration) return;
      state = state.copyWith(users: users, loadingUsers: false);
    } on Object catch (error) {
      if (generation != _searchGeneration) return;
      state = state.copyWith(loadingUsers: false, error: error);
    }
  }

  Future<void> loadRecentPlayers({String? clubId, String? search}) async {
    final generation = ++_recentGeneration;
    state = state.copyWith(loadingRecentPlayers: true, clearError: true);
    try {
      final recent = await ref.read(rosterServiceProvider).getHostRecentPlayers(
            clubId: clubId,
            search: search,
          );
      if (generation != _recentGeneration) return;
      state = state.copyWith(
        recentPlayers: recent,
        loadingRecentPlayers: false,
      );
    } on Object catch (error) {
      if (generation != _recentGeneration) return;
      state = state.copyWith(loadingRecentPlayers: false, error: error);
    }
  }

  Future<bool> submit(List<HostPlayerDraft> players) async {
    if (state.submitting) return false;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .createPlayers(
            sessionId,
            players.map((player) => player.toJson()).toList(growable: false),
          );
      state = state.copyWith(submitting: false);
      ref
        ..invalidate(sessionDetailProvider(sessionId))
        ..invalidate(paymentLedgerProvider(sessionId));
      return true;
    } on Object catch (error) {
      state = state.copyWith(submitting: false, error: error);
      return false;
    }
  }
}

final hostAddPlayersControllerProvider =
    NotifierProvider.family<
      HostAddPlayersController,
      HostAddPlayersState,
      String
    >(HostAddPlayersController.new);
