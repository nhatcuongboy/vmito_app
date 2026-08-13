import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';
import 'package:vmito_app/features/session/presentation/player/session_filter_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _LocationPreferencesController extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(
    preferredCity: 'Hồ Chí Minh',
    isRestored: true,
  );
}

class _Harness extends StatefulWidget {
  const _Harness({required this.onResult});
  final ValueChanged<BrowseSessionFilters> onResult;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Future<void> _open() async {
    final result = await showModalBottomSheet<BrowseSessionFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SessionFilterSheet(
        initial: BrowseSessionFilters(
          search: 'Sunday',
          city: 'Hồ Chí Minh',
        ),
      ),
    );
    if (result != null) widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(onPressed: _open, child: const Text('Open')),
    ),
  );
}

Widget _app(ValueChanged<BrowseSessionFilters> onResult) => ProviderScope(
  overrides: [
    locationPreferencesControllerProvider.overrideWith(
      _LocationPreferencesController.new,
    ),
    newAdminUnitsProvider.overrideWith(
      (ref) async => const [
        NewAdminUnit(
          city: 'Hồ Chí Minh',
          wards: ['Phường An Đông', 'Phường An Hội Đông'],
        ),
        NewAdminUnit(city: 'Hà Nội', wards: ['Phường Ba Đình']),
      ],
    ),
    deviceLocationServiceProvider.overrideWithValue(
      () async => const DeviceCoordinates(
        latitude: 10.77,
        longitude: 106.69,
      ),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('vi'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _Harness(onResult: onResult),
  ),
);

void main() {
  testWidgets('applies multi-select, near-me and validated fee filters', (
    tester,
  ) async {
    BrowseSessionFilters? result;
    await tester.pumpWidget(_app((value) => result = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('session-filter-time-morning')));
    await tester.tap(find.byKey(const Key('session-filter-has-slots')));
    await tester.tap(find.byKey(const Key('session-filter-near-me')));
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(
          of: find.byType(SessionFilterSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('session-filter-sport-pickleball')),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const Key('session-filter-sport-pickleball')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('session-filter-level-4')),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const Key('session-filter-level-4')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('session-filter-min-fee')),
      300,
      scrollable: scrollable,
    );
    await tester.enterText(
      find.byKey(const Key('session-filter-min-fee')),
      '250000',
    );
    await tester.tap(find.byKey(const Key('session-filter-apply')));
    await tester.pump();
    expect(find.text('Chi phí tối thiểu không được lớn hơn tối đa.'), findsOne);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const Key('session-filter-min-fee')),
      '50000',
    );
    await tester.tap(find.byKey(const Key('session-filter-apply')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.search, 'Sunday');
    expect(result!.timeRanges, {SessionTimeRange.morning});
    expect(result!.hasSlots, isTrue);
    expect(result!.nearMe, isTrue);
    expect(result!.latitude, 10.77);
    expect(result!.sports, {SessionSport.pickleball});
    expect(result!.levels, {4});
    expect(result!.minFee, 50000);
  });

  testWidgets('reset keeps search and restores the preferred city', (
    tester,
  ) async {
    BrowseSessionFilters? result;
    await tester.pumpWidget(_app((value) => result = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('session-filter-reset')));
    await tester.pumpAndSettle();

    expect(result?.search, 'Sunday');
    expect(result?.city, 'Hồ Chí Minh');
    expect(result?.activeCount, 0);
  });
}
