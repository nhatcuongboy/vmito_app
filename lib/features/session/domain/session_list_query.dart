import 'package:vmito_app/features/session/domain/session.dart';

/// Shared filters for the authenticated hosted and joined session lists.
class SessionListQuery {
  const SessionListQuery({
    this.page = 1,
    this.limit = 20,
    this.search,
    this.status,
    this.excludedStatuses = const [],
    this.sortBy = 'date',
    this.sortOrder = 'asc',
  });

  final int page;
  final int limit;
  final String? search;
  final SessionStatus? status;
  final List<SessionStatus> excludedStatuses;
  final String sortBy;
  final String sortOrder;

  SessionListQuery copyWith({int? page, String? search}) => SessionListQuery(
    page: page ?? this.page,
    limit: limit,
    search: search ?? this.search,
    status: status,
    excludedStatuses: excludedStatuses,
    sortBy: sortBy,
    sortOrder: sortOrder,
  );
}
