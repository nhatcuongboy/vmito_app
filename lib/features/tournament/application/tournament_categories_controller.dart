import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_category_service.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_category_form.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

/// Categories of one tournament, keyed by the tournament's real id (the
/// create endpoint needs it). Format and scoring edits also go through
/// [update], since the backend exposes a single `PUT /categories/:id`.
class TournamentCategoriesController
    extends TournamentResourceController<TournamentCategory> {
  TournamentCategoriesController(super.tournamentId);

  @override
  TournamentPermission get permission => TournamentPermission.structure;

  @override
  String itemId(TournamentCategory item) => item.id;

  @override
  Future<List<TournamentCategory>> fetch() =>
      ref.read(categoryServiceProvider).list(tournamentId);

  Future<bool> save(
    CategoryDraft draft, {
    required scoring.SportType sport,
    String? id,
  }) => mutate((items) async {
    final service = ref.read(categoryServiceProvider);
    final saved = id == null
        ? await service.create(tournamentId, draft, sport: sport)
        : await service.update(id, draft.toJson());
    return _replace(items, saved);
  });

  Future<bool> update(String id, Map<String, dynamic> changes) => mutate(
    (items) async => _replace(
      items,
      await ref.read(categoryServiceProvider).update(id, changes),
    ),
  );

  Future<bool> delete(String id) => mutate((items) async {
    await ref.read(categoryServiceProvider).delete(id);
    return items.where((item) => item.id != id).toList();
  });

  // Keeps list order (creation order, as served) instead of appending edits
  // to the end like `upsert`.
  List<TournamentCategory> _replace(
    List<TournamentCategory> items,
    TournamentCategory saved,
  ) {
    final index = items.indexWhere((item) => item.id == saved.id);
    return index < 0 ? [...items, saved] : ([...items]..[index] = saved);
  }
}

final NotifierProviderFamily<
  TournamentCategoriesController,
  TournamentResourceState<TournamentCategory>,
  String
>
tournamentCategoriesProvider =
    NotifierProvider.family<
      TournamentCategoriesController,
      TournamentResourceState<TournamentCategory>,
      String
    >(TournamentCategoriesController.new);
