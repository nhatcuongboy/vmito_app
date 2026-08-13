import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/presentation/player/create_session_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Widget _app() => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const CreateSessionScreen(),
  ),
);

void main() {
  testWidgets('mobile form uses sticky submit and reports required fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Thông tin chung'), findsOneWidget);
    expect(find.byKey(const Key('create-session-submit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên kèo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('court rows can be added without overflowing a wide layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-court')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('add-court')));
    await tester.pump();

    expect(find.byKey(const ValueKey('court-number-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
