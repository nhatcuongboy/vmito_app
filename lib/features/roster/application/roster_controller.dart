// Riverpod providers and state classes have obvious types.
// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/roster/data/roster_service.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/roster/domain/player_profile_draft.dart';
import 'package:vmito_app/features/roster/domain/player_profile_stats.dart';

class RosterState {
  const RosterState({
    this.profiles = const [],
    this.selectedClubFilter,
    this.searchQuery = '',
    this.selectedStatus = PlayerProfileStatus.active,
    this.isLoading = false,
    this.submitting = false,
    this.error,
  });

  final List<PlayerProfile> profiles;
  final String? selectedClubFilter;
  final String searchQuery;
  final PlayerProfileStatus selectedStatus;
  final bool isLoading;
  final bool submitting;
  final Object? error;

  RosterState copyWith({
    List<PlayerProfile>? profiles,
    String? selectedClubFilter,
    bool clearClubFilter = false,
    String? searchQuery,
    PlayerProfileStatus? selectedStatus,
    bool? isLoading,
    bool? submitting,
    Object? error,
    bool clearError = false,
  }) =>
      RosterState(
        profiles: profiles ?? this.profiles,
        selectedClubFilter: clearClubFilter
            ? null
            : (selectedClubFilter ?? this.selectedClubFilter),
        searchQuery: searchQuery ?? this.searchQuery,
        selectedStatus: selectedStatus ?? this.selectedStatus,
        isLoading: isLoading ?? this.isLoading,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
      );
}

class RosterController extends Notifier<RosterState> {
  int _loadGeneration = 0;

  @override
  RosterState build() {
    unawaited(Future.microtask(loadProfiles));
    return const RosterState(isLoading: true);
  }

  Future<void> loadProfiles() async {
    final gen = ++_loadGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final clubFilter = state.selectedClubFilter;
      final effectiveClubId =
          clubFilter == null || clubFilter == 'all' ? null : clubFilter;
      final profiles = await ref.read(rosterServiceProvider).getProfiles(
            clubId: effectiveClubId,
            search: state.searchQuery,
            status: state.selectedStatus.wireValue,
          );
      if (gen != _loadGeneration) return;
      state = state.copyWith(profiles: profiles, isLoading: false);
    } on Object catch (e) {
      if (gen != _loadGeneration) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void setClubFilter(String? clubId) {
    if (state.selectedClubFilter == clubId) return;
    if (clubId == null || clubId == 'all') {
      state = state.copyWith(clearClubFilter: true);
    } else {
      state = state.copyWith(selectedClubFilter: clubId);
    }
    unawaited(loadProfiles());
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    unawaited(loadProfiles());
  }

  void setStatusFilter(PlayerProfileStatus status) {
    if (state.selectedStatus == status) return;
    state = state.copyWith(selectedStatus: status);
    unawaited(loadProfiles());
  }

  Future<bool> createProfile(CreatePlayerProfileDraft draft) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final created =
          await ref.read(rosterServiceProvider).createProfile(draft);
      state = state.copyWith(
        submitting: false,
        profiles: [created, ...state.profiles],
      );
      if (draft.clubId != null) {
        ref.invalidate(clubRosterProvider(draft.clubId!));
      }
      return true;
    } on Object catch (e) {
      state = state.copyWith(submitting: false, error: e);
      return false;
    }
  }

  Future<bool> updateProfile(
    String id,
    UpdatePlayerProfileDraft draft,
  ) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final updated =
          await ref.read(rosterServiceProvider).updateProfile(id, draft);
      state = state.copyWith(
        submitting: false,
        profiles: state.profiles
            .map((profile) => profile.id == id ? updated : profile)
            .toList(),
      );
      if (updated.clubId != null) {
        ref.invalidate(clubRosterProvider(updated.clubId!));
      }
      return true;
    } on Object catch (e) {
      state = state.copyWith(submitting: false, error: e);
      return false;
    }
  }

  Future<bool> deleteProfile(String id) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await ref.read(rosterServiceProvider).deleteProfile(id);
      state = state.copyWith(
        submitting: false,
        profiles: state.profiles.where((p) => p.id != id).toList(),
      );
      return true;
    } on Object catch (e) {
      state = state.copyWith(submitting: false, error: e);
      return false;
    }
  }

  Future<bool> promoteProfile(
    String id,
    PromoteProfileDraft draft,
  ) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await ref.read(rosterServiceProvider).promoteProfile(id, draft);
      state = state.copyWith(
        submitting: false,
        profiles: state.profiles
            .map(
              (p) => p.id == id
                  ? PlayerProfile(
                      id: p.id,
                      name: draft.name ?? p.name,
                      gender: p.gender,
                      phone: p.phone,
                      level: p.level,
                      notes: p.notes,
                      status: PlayerProfileStatus.promoted,
                      clubId: p.clubId,
                      club: p.club,
                      linkedUserId: p.linkedUserId,
                      promotedAt: DateTime.now(),
                      totalSessions: p.totalSessions,
                      lastPlayedAt: p.lastPlayedAt,
                      lastSessionName: p.lastSessionName,
                      points: p.points,
                      tier: p.tier,
                      createdAt: p.createdAt,
                      updatedAt: DateTime.now(),
                    )
                  : p,
            )
            .toList(),
      );
      return true;
    } on Object catch (e) {
      state = state.copyWith(submitting: false, error: e);
      return false;
    }
  }
}

final rosterControllerProvider =
    NotifierProvider<RosterController, RosterState>(RosterController.new);

final clubRosterProvider =
    FutureProvider.family<List<PlayerProfile>, String>((ref, clubId) {
  return ref.watch(rosterServiceProvider).getProfiles(clubId: clubId);
});

final playerProfileStatsProvider =
    FutureProvider.family<PlayerProfileStats, String>((ref, id) {
  return ref.watch(rosterServiceProvider).getStats(id);
});
