import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

class TournamentManagementState {
  const TournamentManagementState({
    this.isLoading = false,
    this.isMutating = false,
    this.hasLoaded = false,
    this.tournament,
    this.access,
    this.error,
  });

  final bool isLoading;
  final bool isMutating;
  final bool hasLoaded;
  final TournamentDetail? tournament;
  final TournamentMyAccess? access;
  final Object? error;

  bool get canManage => access?.canManage ?? false;
  bool get isHostOrAdmin => access?.isHostOrAdmin ?? false;

  TournamentManagementState copyWith({
    bool? isLoading,
    bool? isMutating,
    bool? hasLoaded,
    TournamentDetail? tournament,
    TournamentMyAccess? access,
    Object? error = _unset,
  }) => TournamentManagementState(
    isLoading: isLoading ?? this.isLoading,
    isMutating: isMutating ?? this.isMutating,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    tournament: tournament ?? this.tournament,
    access: access ?? this.access,
    error: identical(error, _unset) ? this.error : error,
  );
}

const _unset = Object();

class TournamentManagementController
    extends Notifier<TournamentManagementState> {
  TournamentManagementController(this.idOrSlug);

  final String idOrSlug;

  TournamentManagementService get _management =>
      ref.read(tournamentManagementServiceProvider);

  @override
  TournamentManagementState build() => const TournamentManagementState();

  Future<void> load({bool force = false}) async {
    if (state.isLoading || (state.hasLoaded && !force)) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tournament = await ref
          .read(tournamentServiceProvider)
          .detail(idOrSlug);
      state = state.copyWith(tournament: tournament);
      TournamentMyAccess access;
      try {
        access = await _management.access(tournament.id);
      } on Object {
        final user = ref.read(authControllerProvider).user;
        final isHost = user?.id == tournament.hostId;
        final isAdmin = user?.role == UserRole.admin;
        if (!isHost && !isAdmin) rethrow;
        access = TournamentMyAccess(
          tournamentId: tournament.id,
          isHost: isHost,
          isAdmin: isAdmin,
          permissions: const {},
        );
      }
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        tournament: tournament,
        access: access,
        error: null,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: error,
      );
    }
  }

  Future<TournamentDetail> update(Map<String, dynamic> changes) async {
    if (state.isMutating || state.tournament == null) {
      throw StateError('Tournament mutation is already in progress');
    }
    state = state.copyWith(isMutating: true, error: null);
    try {
      final updated = await _management.updateTournament(
        state.tournament!.id,
        changes,
      );
      state = state.copyWith(isMutating: false, tournament: updated);
      ref
        ..invalidate(tournamentTitleProvider(idOrSlug))
        ..invalidate(tournamentBrowseControllerProvider);
      return updated;
    } on Object catch (error) {
      state = state.copyWith(isMutating: false, error: error);
      rethrow;
    }
  }

  Future<TournamentDetail> duplicate(DuplicateTournamentDraft draft) async {
    if (state.isMutating || state.tournament == null) {
      throw StateError('Tournament mutation is already in progress');
    }
    state = state.copyWith(isMutating: true, error: null);
    try {
      final duplicated = await _management.duplicateTournament(
        state.tournament!.id,
        draft,
      );
      state = state.copyWith(isMutating: false);
      ref.invalidate(tournamentBrowseControllerProvider);
      return duplicated;
    } on Object catch (error) {
      state = state.copyWith(isMutating: false, error: error);
      rethrow;
    }
  }

  Future<void> delete() async {
    if (state.isMutating || state.tournament == null) return;
    state = state.copyWith(isMutating: true, error: null);
    try {
      await _management.deleteTournament(state.tournament!.id);
      state = state.copyWith(isMutating: false);
      ref.invalidate(tournamentBrowseControllerProvider);
    } on Object catch (error) {
      state = state.copyWith(isMutating: false, error: error);
      rethrow;
    }
  }
}

final NotifierProviderFamily<
  TournamentManagementController,
  TournamentManagementState,
  String
>
tournamentManagementControllerProvider =
    NotifierProvider.family<
      TournamentManagementController,
      TournamentManagementState,
      String
    >(TournamentManagementController.new);

// Riverpod's generated family type is intentionally inferred at the boundary.
// ignore: specify_nonobvious_property_types
final tournamentManagersProvider =
    FutureProvider.family<List<TournamentManager>, String>(
      (ref, tournamentId) =>
          ref.watch(tournamentManagementServiceProvider).managers(tournamentId),
    );

// Riverpod's generated family type is intentionally inferred at the boundary.
// ignore: specify_nonobvious_property_types
final tournamentUserSearchProvider =
    FutureProvider.family<List<TournamentUserOption>, String>((ref, query) {
      if (query.trim().length < 2) return const [];
      return ref.watch(tournamentManagementServiceProvider).searchUsers(query);
    });

final tournamentImageLibraryProvider =
    FutureProvider<List<TournamentImageAsset>>(
      (ref) => ref.watch(tournamentManagementServiceProvider).images(),
    );

// Riverpod's generated family type is intentionally inferred at the boundary.
// ignore: specify_nonobvious_property_types
final tournamentVenueSearchProvider =
    FutureProvider.family<List<Venue>, String>(
      (ref, query) =>
          ref.watch(tournamentManagementServiceProvider).searchVenues(query),
    );

// Riverpod's generated family type is intentionally inferred at the boundary.
// ignore: specify_nonobvious_property_types
final tournamentManageAccessProvider =
    FutureProvider.family<TournamentMyAccess?, String>((ref, idOrSlug) async {
      final user = ref.watch(authControllerProvider).user;
      if (user == null || user.isGuest) return null;
      try {
        return await ref
            .watch(tournamentManagementServiceProvider)
            .access(idOrSlug);
      } on Object {
        return null;
      }
    });

class TournamentManagerController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> add(
    String tournamentId,
    String userId,
    Set<TournamentPermission> permissions,
  ) => _run(
    tournamentId,
    () => ref
        .read(tournamentManagementServiceProvider)
        .addManager(tournamentId, userId, permissions),
  );

  Future<void> update(
    String tournamentId,
    String userId,
    Set<TournamentPermission> permissions,
  ) => _run(
    tournamentId,
    () => ref
        .read(tournamentManagementServiceProvider)
        .updateManager(tournamentId, userId, permissions),
  );

  Future<void> remove(String tournamentId, String userId) => _run(
    tournamentId,
    () => ref
        .read(tournamentManagementServiceProvider)
        .removeManager(tournamentId, userId),
  );

  Future<void> _run(
    String tournamentId,
    Future<Object?> Function() operation,
  ) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await operation();
      state = const AsyncData(null);
      ref.invalidate(tournamentManagersProvider(tournamentId));
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final tournamentManagerControllerProvider =
    NotifierProvider<TournamentManagerController, AsyncValue<void>>(
      TournamentManagerController.new,
    );
