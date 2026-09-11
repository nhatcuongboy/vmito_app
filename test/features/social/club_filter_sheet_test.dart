import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/social/domain/club_browse_filters.dart';
import 'package:vmito_app/features/social/presentation/widgets/club_filter_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _LocationPreferencesController extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(
    preferredCity: 'Hồ Chí Minh',
    isRestored: true,
  );

  @override
  Future<void> selectCity(String? city) async {
    state = state.copyWith(preferredCity: city);
  }

  @override
  Future<void> selectAll() async {
    state = state.copyWith(clearPreferredCity: true);
  }
}

class _Harness extends StatefulWidget {
  const _Harness({required this.initial, required this.onResult});

  final ClubBrowseFilters initial;
  final ValueChanged<ClubBrowseFilters> onResult;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Future<void> _open() async {
    final result = await showModalBottomSheet<ClubBrowseFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ClubFilterSheet(initial: widget.initial),
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

Widget _app(
  ValueChanged<ClubBrowseFilters> onResult, {
  ClubBrowseFilters initial = const ClubBrowseFilters(),
}) => ProviderScope(
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
  ],
  child: MaterialApp(
    locale: const Locale('vi'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _Harness(initial: initial, onResult: onResult),
  ),
);

void main() {
  testWidgets('renders the area, activity-time, and level sections', (
    tester,
  ) async {
    await tester.pumpWidget(_app((_) {}));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('club-filter-area-section')), findsOneWidget);
    expect(
      find.byKey(const Key('club-filter-activity-time-section')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('club-filter-level-section')), findsOneWidget);
    // "Chỉ mục yêu thích" no longer belongs in this sheet.
    expect(find.textContaining('yêu thích'), findsNothing);
  });

  testWidgets('applies selected weekday, buổi, and level filters', (
    tester,
  ) async {
    ClubBrowseFilters? result;
    await tester.pumpWidget(_app((value) => result = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('club-filter-weekday-1')));
    await tester.tap(find.byKey(const Key('club-filter-period-morning')));
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(
          of: find.byType(ClubFilterSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('club-filter-level-3')),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const Key('club-filter-level-3')));
    await tester.tap(find.byKey(const Key('club-filter-apply')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.activeDays, {1});
    expect(result!.activePeriods, {ClubActivityPeriod.morning});
    expect(result!.levels, {3});
  });

  testWidgets('reset clears every filter but keeps the preferred city', (
    tester,
  ) async {
    ClubBrowseFilters? result;
    await tester.pumpWidget(
      _app(
        (value) => result = value,
        initial: const ClubBrowseFilters(
          city: 'Hồ Chí Minh',
          levels: {3},
          activeDays: {1},
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('club-filter-reset')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isEmpty, isTrue);
    expect(result!.city, 'Hồ Chí Minh');
  });
}
