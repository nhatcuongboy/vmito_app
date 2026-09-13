import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_category_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_pair_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_player_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/domain/tournament_pair_draft.dart';

typedef CategoryRegistrationsKey = ({String tournamentId, String categoryId});

/// Registrations of one category. Like the web panel, every mutation refetches
/// the category's registrations rather than patching locally — pair and player
/// side effects (auto-created players, deleted legacy players) are server-side.
class TournamentRegistrationsController
    extends TournamentResourceController<TournamentRegistration> {
  TournamentRegistrationsController(CategoryRegistrationsKey key)
    : categoryId = key.categoryId,
      super(key.tournamentId);

  final String categoryId;

  @override
  TournamentPermission get permission => TournamentPermission.participants;

  @override
  String itemId(TournamentRegistration item) => item.id;

  @override
  Future<List<TournamentRegistration>> fetch() =>
      ref.read(tournamentServiceProvider).registrations(categoryId);

  CategoryService get _categories => ref.read(categoryServiceProvider);

  Future<bool> _refetchAfter(Future<void> Function() operation) =>
      mutate((_) async {
        await operation();
        return fetch();
      });

  /// One entry: a team category gets an empty pair; an individual category
  /// gets a new roster player.
  Future<bool> addOne(TournamentCategory category, String name) =>
      _refetchAfter(() async {
        if (category.registrationMode == TournamentRegistrationMode.team) {
          final pairId = await ref
              .read(tournamentPairServiceProvider)
              .create(
                tournamentId,
                TournamentPairDraft(
                  name: name,
                  playerIds: const [],
                  type: category.type,
                ),
              );
          await _categories.createRegistration(categoryId, pairId: pairId);
        } else {
          final player = await ref
              .read(tournamentPlayerServiceProvider)
              .save(tournamentId, PlayerDraft(name: name));
          await _categories.createRegistration(categoryId, playerId: player.id);
          _reloadRoster();
        }
      });

  Future<bool> addMany(List<String> names) => _refetchAfter(() async {
    await _categories.bulkRegistrations(categoryId, names: names);
    _reloadRoster();
  });

  Future<bool> addFromRoster(List<String> playerIds) => _refetchAfter(
    () => _categories.bulkRegistrations(categoryId, playerIds: playerIds),
  );

  Future<bool> remove(String registrationId) => _refetchAfter(
    () => _categories.deleteRegistration(categoryId, registrationId),
  );

  Future<bool> renamePlayer(String playerId, String name) =>
      _refetchAfter(() async {
        await ref.read(tournamentPlayerServiceProvider).rename(playerId, name);
        _reloadRoster();
      });

  Future<bool> saveTeam(
    TournamentCategory category,
    TournamentRegistration registration, {
    required String name,
    required List<String> memberIds,
  }) => _refetchAfter(() async {
    final draft = TournamentPairDraft(
      name: name,
      playerIds: memberIds,
      type: category.type,
    );
    final pairId = registration.tournamentPairId;
    if (pairId != null) {
      await ref.read(tournamentPairServiceProvider).update(pairId, draft);
    } else {
      await _categories.convertToPair(categoryId, registration.id, draft);
    }
  });

  void _reloadRoster() =>
      ref.invalidate(tournamentPlayersProvider(tournamentId));
}

final NotifierProviderFamily<
  TournamentRegistrationsController,
  TournamentResourceState<TournamentRegistration>,
  CategoryRegistrationsKey
>
tournamentRegistrationsProvider =
    NotifierProvider.family<
      TournamentRegistrationsController,
      TournamentResourceState<TournamentRegistration>,
      CategoryRegistrationsKey
    >(TournamentRegistrationsController.new);
