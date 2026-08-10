import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

class VenueBrowseState {
  const VenueBrowseState({
    this.venues = const [],
    this.filter = const VenueFilter(),
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });
  final List<Venue> venues;
  final VenueFilter filter;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  bool get hasMore => page > 0 && page < totalPages;
}

class VenueBrowseController extends Notifier<VenueBrowseState> {
  @override
  VenueBrowseState build() => const VenueBrowseState();
  Future<void> load({VenueFilter? filter}) async {
    final active = filter ?? state.filter;
    state = VenueBrowseState(
      venues: state.venues,
      filter: active,
      isLoading: true,
    );
    try {
      final result = await ref
          .read(venueServiceProvider)
          .browse(active, page: 1);
      state = VenueBrowseState(
        venues: result.venues,
        filter: active,
        page: result.page,
        totalPages: result.totalPages,
      );
    } on Object catch (error) {
      state = VenueBrowseState(filter: active, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final before = state;
    state = VenueBrowseState(
      venues: before.venues,
      filter: before.filter,
      page: before.page,
      totalPages: before.totalPages,
      isLoadingMore: true,
    );
    try {
      final result = await ref
          .read(venueServiceProvider)
          .browse(before.filter, page: before.page + 1);
      final ids = before.venues.map((venue) => venue.id).toSet();
      state = VenueBrowseState(
        venues: [
          ...before.venues,
          ...result.venues.where((venue) => ids.add(venue.id)),
        ],
        filter: before.filter,
        page: result.page,
        totalPages: result.totalPages,
      );
    } on Object catch (error) {
      state = VenueBrowseState(
        venues: before.venues,
        filter: before.filter,
        page: before.page,
        totalPages: before.totalPages,
        error: error,
      );
    }
  }
}

final venueBrowseControllerProvider =
    NotifierProvider<VenueBrowseController, VenueBrowseState>(
      VenueBrowseController.new,
    );
final FutureProviderFamily<Venue, String> venueDetailProvider = FutureProvider.family<Venue, String>(
  (ref, id) => ref.watch(venueServiceProvider).byId(id),
);
final FutureProviderFamily<List<VenuePriceBook>, String> venuePriceBooksProvider =
    FutureProvider.family<List<VenuePriceBook>, String>(
      (ref, id) => ref.watch(venueServiceProvider).priceBooks(id),
    );
