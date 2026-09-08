import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/session_fee_config_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('stacks fee metadata and actions on a narrow card', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(280, 700);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpCard(tester, width: 280);

    expect(
      find.byKey(const Key('fee-config-header-compact')),
      findsOneWidget,
    );
    expect(
      tester.getCenter(find.byType(Chip)).dy,
      closeTo(tester.getCenter(find.text('Cấu hình phí')).dy, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps actions beside the header content on a wide card', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(700, 700);
    addTearDown(tester.view.reset);

    await _pumpCard(tester, width: 600);

    expect(find.byKey(const Key('fee-config-header-wide')), findsOneWidget);
    expect(find.byIcon(AppIcons.calculator), findsNothing);
    expect(
      tester.widget<Text>(find.text('Cấu hình phí')).style?.fontSize,
      16,
    );
    for (final icon in [AppIcons.edit, AppIcons.refresh]) {
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, icon),
      );
      expect(button.iconSize, 18);
      expect(
        tester.getSize(find.widgetWithIcon(IconButton, icon)).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(
      tester.getCenter(find.byIcon(AppIcons.edit)).dy,
      closeTo(tester.getCenter(find.byType(Chip)).dy, 1),
    );
    expect(
      tester.getBottomRight(find.textContaining('85.000')).dx,
      closeTo(tester.getBottomRight(find.textContaining('70.000')).dx, 1),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(WidgetTester tester, {required double width}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionFeeConfigProvider('s1').overrideWith(
          (ref) async => const SessionFeeConfig(
            maleFee: 85000,
            femaleFee: 70000,
            notes: 'Hao cầu phụ thu 5k',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: const SessionFeeConfigCard(sessionId: 's1'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
