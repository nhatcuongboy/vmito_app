import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';

/// The one mapping from browse filters to the browse request.
///
/// Shared by the browse list and the search suggestions so a suggestion can
/// never show a session that the matching result list would leave out.
extension BrowseSessionsQuery on SessionRepository {
  Future<Page<Session>> browseFiltered(
    BrowseSessionFilters filters, {
    required int page,
    required int limit,
  }) => browseAvailable(
    page: page,
    limit: limit,
    search: filters.search,
    date: filters.date,
    timeRanges: filters.timeRanges,
    levels: filters.levels,
    sports: filters.sports,
    hasSlots: filters.hasSlots ? true : null,
    sessionType: filters.source.name,
    city: filters.city,
    districts: filters.districts,
    minFee: filters.hasCustomFeeRange ? filters.minFee : null,
    maxFee: filters.hasCustomFeeRange ? filters.maxFee : null,
    minCourts: filters.courtCount?.minCourts,
    maxCourts: filters.courtCount?.maxCourts,
    splitEvenly: filters.splitEvenly,
    latitude: filters.nearMe ? filters.latitude : null,
    longitude: filters.nearMe ? filters.longitude : null,
    sortByDistance: filters.nearMe,
    venueId: filters.venueId,
    sortBy: filters.sort.sortBy,
    sortOrder: filters.sort.sortOrder,
  );
}
