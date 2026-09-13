import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_player_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_sponsor_service.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';

class TournamentResourceState<T> {
  const TournamentResourceState({
    this.items = const [],
    this.loading = false,
    this.busy = false,
    this.loaded = false,
    this.error,
  });
  final List<T> items;
  final bool loading;
  final bool busy;
  final bool loaded;
  final Object? error;
}

/// Per-resource state: a failed refresh keeps the existing collection. Mutations
/// merge server responses locally, so they cannot reset another panel's filters.
abstract class TournamentResourceController<T>
    extends Notifier<TournamentResourceState<T>> {
  TournamentResourceController(this.tournamentId);
  final String tournamentId;
  TournamentPermission get permission;
  Future<List<T>> fetch();
  String itemId(T item);

  @override
  TournamentResourceState<T> build() {
    unawaited(
      Future<void>.microtask(() {
        if (ref.mounted) return reload();
      }),
    );
    return TournamentResourceState<T>();
  }

  Future<void> reload() async {
    if (state.loading || state.busy) return;
    state = TournamentResourceState(
      items: state.items,
      loaded: state.loaded,
      loading: true,
    );
    try {
      final items = await fetch();
      if (ref.mounted) {
        state = TournamentResourceState(
          items: List.unmodifiable(items),
          loaded: true,
        );
      }
    } on Object catch (error) {
      if (ref.mounted) {
        state = TournamentResourceState(
          items: state.items,
          loaded: state.loaded,
          error: error,
        );
      }
    }
  }

  Future<bool> mutate(Future<List<T>> Function(List<T>) operation) async {
    if (state.busy || state.loading || !state.loaded) return false;
    final before = state.items;
    state = TournamentResourceState(items: before, loaded: true, busy: true);
    try {
      final access = await ref
          .read(tournamentManagementServiceProvider)
          .access(tournamentId);
      if (!ref.mounted) return false;
      if (!access.isHostOrAdmin && !access.permissions.contains(permission)) {
        throw StateError('Tournament permission revoked');
      }
      final items = await operation(before);
      if (ref.mounted) {
        state = TournamentResourceState(
          items: List.unmodifiable(items),
          loaded: true,
        );
      }
      return true;
    } on Object catch (error) {
      if (ref.mounted) {
        state = TournamentResourceState(
          items: before,
          loaded: true,
          error: error,
        );
      }
      return false;
    }
  }

  List<T> upsert(List<T> items, T item) => [
    for (final existing in items)
      if (itemId(existing) != itemId(item)) existing,
    item,
  ];
}

class TournamentPlayersController
    extends TournamentResourceController<TournamentPlayer> {
  TournamentPlayersController(super.tournamentId);
  @override
  TournamentPermission get permission => TournamentPermission.participants;
  @override
  String itemId(TournamentPlayer item) => item.id;
  @override
  Future<List<TournamentPlayer>> fetch() =>
      ref.read(tournamentPlayerServiceProvider).list(tournamentId);
  Future<bool> save(PlayerDraft draft, {String? id}) => mutate(
    (items) async => upsert(
      items,
      await ref
          .read(tournamentPlayerServiceProvider)
          .save(tournamentId, draft, id: id),
    ),
  );
  Future<bool> delete(String id) => mutate((items) async {
    await ref.read(tournamentPlayerServiceProvider).delete(id);
    return items.where((item) => item.id != id).toList();
  });
  Future<bool> import(List<PlayerImportRow> rows) => mutate(
    (items) async => [
      ...items,
      ...await ref
          .read(tournamentPlayerServiceProvider)
          .bulkCreate(tournamentId, rows),
    ],
  );
}

class TournamentSponsorsController
    extends TournamentResourceController<TournamentSponsor> {
  TournamentSponsorsController(super.tournamentId);
  @override
  TournamentPermission get permission => TournamentPermission.structure;
  @override
  String itemId(TournamentSponsor item) => item.id;
  @override
  Future<List<TournamentSponsor>> fetch() =>
      ref.read(tournamentSponsorServiceProvider).list(tournamentId);
  Future<bool> save(SponsorDraft draft, {String? id}) => mutate(
    (items) async => upsert(
      items,
      await ref
          .read(tournamentSponsorServiceProvider)
          .save(tournamentId, draft, id: id),
    ),
  );
  Future<bool> delete(String id) => mutate((items) async {
    await ref.read(tournamentSponsorServiceProvider).delete(id);
    return items.where((item) => item.id != id).toList();
  });
}

final NotifierProviderFamily<
  TournamentPlayersController,
  TournamentResourceState<TournamentPlayer>,
  String
>
tournamentPlayersProvider =
    NotifierProvider.family<
      TournamentPlayersController,
      TournamentResourceState<TournamentPlayer>,
      String
    >(TournamentPlayersController.new);
final NotifierProviderFamily<
  TournamentSponsorsController,
  TournamentResourceState<TournamentSponsor>,
  String
>
tournamentSponsorsProvider =
    NotifierProvider.family<
      TournamentSponsorsController,
      TournamentResourceState<TournamentSponsor>,
      String
    >(TournamentSponsorsController.new);
final FutureProviderFamily<List<TournamentMatch>, String>
tournamentPlayerMatchesProvider = FutureProvider.autoDispose
    .family<List<TournamentMatch>, String>(
      (ref, id) => ref.watch(tournamentPlayerServiceProvider).matches(id),
    );

class TournamentResourceImageController
    extends Notifier<AsyncValue<TournamentImageAsset?>> {
  @override
  AsyncValue<TournamentImageAsset?> build() => const AsyncData(null);

  Future<TournamentImageAsset?> upload(Uint8List bytes, String filename) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(tournamentManagementServiceProvider)
          .uploadImage(bytes: bytes, filename: filename, category: 'OTHER');
      final asset = TournamentImageAsset(
        id: result.publicId,
        url: result.url,
        publicId: result.publicId,
      );
      if (ref.mounted) state = AsyncData(asset);
      return asset;
    } on Object catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      rethrow;
    }
  }
}

final NotifierProvider<
  TournamentResourceImageController,
  AsyncValue<TournamentImageAsset?>
>
tournamentResourceImageProvider =
    NotifierProvider.autoDispose<
      TournamentResourceImageController,
      AsyncValue<TournamentImageAsset?>
    >(
      TournamentResourceImageController.new,
    );
