import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/address_display.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/app_address_text.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TestLocationPreferencesController extends LocationPreferencesController {
  _TestLocationPreferencesController(this.value);

  final bool value;

  @override
  LocationPreferences build() => LocationPreferences(
    showNewAddress: value,
    isRestored: true,
  );
}

void main() {
  group('resolveAppAddress', () {
    test(
      'uses the complete new address without legacy administrative fields',
      () {
        final result = resolveAppAddress(
          showNewAddress: true,
          address: '12 Đường Cũ',
          district: 'Quận Cũ',
          city: 'Hồ Chí Minh',
          newAddress: '12 Đường Mới, Phường Mới, Thành phố Mới',
        );

        expect(result.text, '12 Đường Mới, Phường Mới, Thành phố Mới');
        expect(result.isNew, isTrue);
      },
    );

    test('joins separate new-address administrative fields', () {
      final result = resolveAppAddress(
        showNewAddress: true,
        newAddress: '12 Đường Mới',
        newDistrict: 'Phường Mới',
        newCity: 'Thành phố Mới',
      );

      expect(result.text, '12 Đường Mới, Phường Mới, Thành phố Mới');
      expect(result.isNew, isTrue);
    });

    test(
      'falls back to the complete legacy address when disabled or missing',
      () {
        expect(
          resolveAppAddress(
            showNewAddress: false,
            address: '12 Đường Cũ',
            district: 'Quận Cũ',
            city: 'Hồ Chí Minh',
            newAddress: '12 Đường Mới',
          ).text,
          '12 Đường Cũ, Quận Cũ, Hồ Chí Minh',
        );
        expect(
          resolveAppAddress(
            showNewAddress: true,
            address: '12 Đường Cũ',
            district: 'Quận Cũ',
            city: 'Hồ Chí Minh',
          ).text,
          '12 Đường Cũ, Quận Cũ, Hồ Chí Minh',
        );
      },
    );

    test('ignores empty parts', () {
      final result = resolveAppAddress(
        showNewAddress: false,
        address: '  ',
        district: 'Quận 1',
        city: null,
      );

      expect(result.text, 'Quận 1');
      expect(result.isEmpty, isFalse);
    });
  });

  group('resolveCompactAddressArea', () {
    test('uses new ward and city and removes administrative prefixes', () {
      expect(
        resolveCompactAddressArea(
          showNewAddress: true,
          district: 'Quận Cũ',
          city: 'Thành phố Cũ',
          newDistrict: 'Phường Tân Phú',
          newCity: 'Thành phố Mới',
        ),
        'Tân Phú',
      );
    });

    test('uses legacy district when new-address mode is disabled', () {
      expect(
        resolveCompactAddressArea(
          showNewAddress: false,
          district: 'Quận Cũ',
          city: 'Thành phố Cũ',
          newDistrict: 'Phường Tân Phú',
          newCity: 'Thành phố Mới',
        ),
        'Quận Cũ',
      );
    });

    test('does not expose only-new administrative fields when disabled', () {
      expect(
        resolveCompactAddressArea(
          showNewAddress: false,
          newDistrict: 'Phường Tân Phú',
          newCity: 'Thành phố Mới',
        ),
        isNull,
      );
    });

    test('falls back to city when no district is available', () {
      expect(
        resolveCompactAddressArea(
          showNewAddress: true,
          city: 'Thành phố Mới',
        ),
        'Thành phố Mới',
      );
    });
  });

  testWidgets('AppAddressText follows the setting and shows the new badge', (
    tester,
  ) async {
    Future<void> pump(bool showNewAddress) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(showNewAddress),
          overrides: [
            locationPreferencesControllerProvider.overrideWith(
              () => _TestLocationPreferencesController(showNewAddress),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('vi'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AppAddressText(
                address: '12 Đường Cũ',
                district: 'Quận Cũ',
                city: 'Hồ Chí Minh',
                newAddress: '12 Đường Mới',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(true);
    expect(find.textContaining('12 Đường Mới'), findsOneWidget);
    expect(find.text('Mới'), findsOneWidget);
    expect(find.text('12 Đường Cũ, Quận Cũ, Hồ Chí Minh'), findsNothing);

    await pump(false);
    expect(find.text('12 Đường Cũ, Quận Cũ, Hồ Chí Minh'), findsOneWidget);
    expect(find.text('Mới'), findsNothing);
  });
}
