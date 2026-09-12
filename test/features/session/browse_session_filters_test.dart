import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';

void main() {
  test('counts non-search filters and preserves search while editing', () {
    const filters = BrowseSessionFilters(
      search: 'Sunday',
      levels: {4, 5},
      hasSlots: true,
      source: SessionSource.facebook,
      sports: {SessionSport.badminton},
      courtCount: SessionCourtCountFilter.fourPlus,
    );
    expect(filters.activeCount, 5);
    expect(filters.courtCount?.minCourts, 4);
    expect(filters.courtCount?.maxCourts, isNull);
    expect(filters.copyWith(hasSlots: false).search, 'Sunday');
    expect(filters.copyWith(levels: {}).levels, isEmpty);
    expect(filters.copyWith(clearCourtCount: true).courtCount, isNull);
  });

  test('maps every court-count option to its API bounds', () {
    expect(SessionCourtCountFilter.one.minCourts, 1);
    expect(SessionCourtCountFilter.one.maxCourts, 1);
    expect(SessionCourtCountFilter.two.minCourts, 2);
    expect(SessionCourtCountFilter.two.maxCourts, 2);
    expect(SessionCourtCountFilter.three.minCourts, 3);
    expect(SessionCourtCountFilter.three.maxCourts, 3);
    expect(SessionCourtCountFilter.fourPlus.minCourts, 4);
    expect(SessionCourtCountFilter.fourPlus.maxCourts, isNull);
  });

  test('city and districts are never counted and reset preserves search', () {
    const filters = BrowseSessionFilters(
      search: 'Sunday',
      city: 'Hồ Chí Minh',
      districts: {'Phường An Đông'},
      minFee: 50000,
    );

    expect(filters.activeCount, 1);
    final reset = filters.reset(preferredCity: 'Hà Nội');
    expect(reset.search, 'Sunday');
    expect(reset.city, 'Hà Nội');
    expect(reset.activeCount, 0);
  });
}
