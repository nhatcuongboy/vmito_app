import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/google_places_service.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class TournamentPlaceSuggestion {
  const TournamentPlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
}

class TournamentPlaceDetails {
  const TournamentPlaceDetails({
    required this.placeId,
    required this.address,
    this.latitude,
    this.longitude,
    this.district,
    this.city,
  });

  final String placeId;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? district;
  final String? city;
}

class TournamentCreateController
    extends Notifier<AsyncValue<TournamentSummary?>> {
  @override
  AsyncValue<TournamentSummary?> build() => const AsyncData(null);

  void reset() => state = const AsyncData(null);

  Future<TournamentSummary?> submit(TournamentCreateRequest request) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(tournamentServiceProvider).create(request),
    );
    state = result;
    if (result.hasValue) {
      ref.invalidate(tournamentBrowseControllerProvider);
    }
    return result.asData?.value;
  }

  Future<List<TournamentPlaceSuggestion>> searchPlaces({
    required String input,
    required String language,
  }) async {
    final values = await ref
        .read(googlePlacesServiceProvider)
        .autocomplete(input: input, language: language);
    return [
      for (final value in values)
        TournamentPlaceSuggestion(
          placeId: value.placeId,
          primaryText: value.primaryText,
          secondaryText: value.secondaryText,
        ),
    ];
  }

  Future<TournamentPlaceDetails> placeDetails({
    required String placeId,
    required String language,
  }) async {
    final value = await ref
        .read(googlePlacesServiceProvider)
        .details(placeId: placeId, language: language);
    return TournamentPlaceDetails(
      placeId: value.placeId,
      address: value.address,
      latitude: value.latitude,
      longitude: value.longitude,
      district: value.district,
      city: value.city,
    );
  }
}

final tournamentCreateControllerProvider =
    NotifierProvider<
      TournamentCreateController,
      AsyncValue<TournamentSummary?>
    >(TournamentCreateController.new);
