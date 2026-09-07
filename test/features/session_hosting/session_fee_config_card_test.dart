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
      tester.getTopLeft(find.byType(Chip)).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.text('Cấu hình phí buổi chơi')).dy,
      ),
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
    expect(
      tester.getTopLeft(find.byIcon(AppIcons.edit)).dy,
      lessThan(tester.getTopLeft(find.byType(Chip)).dy),
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
