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
    );
    expect(filters.activeCount, 4);
    expect(filters.copyWith(hasSlots: false).search, 'Sunday');
    expect(filters.copyWith(levels: {}).levels, isEmpty);
  });

  test('default city is not counted and reset preserves search', () {
    const filters = BrowseSessionFilters(
      search: 'Sunday',
      city: 'Hồ Chí Minh',
      districts: {'Phường An Đông'},
      minFee: 50000,
    );

    expect(filters.activeCount, 2);
    final reset = filters.reset(preferredCity: 'Hà Nội');
    expect(reset.search, 'Sunday');
    expect(reset.city, 'Hà Nội');
    expect(reset.activeCount, 0);
  });
}
