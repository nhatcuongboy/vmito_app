import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/application/browse_sessions_controller.dart';

void main() {
  test('counts non-search filters and preserves search while editing', () {
    const filters = BrowseSessionFilters(
      search: 'Sunday',
      level: 4,
      hasSlots: true,
      source: SessionSource.facebook,
    );
    expect(filters.activeCount, 3);
    expect(filters.copyWith(hasSlots: false).search, 'Sunday');
    expect(filters.withLevel(null).level, isNull);
  });
}
