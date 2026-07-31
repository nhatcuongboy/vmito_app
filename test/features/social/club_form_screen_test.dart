import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/presentation/club_form_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('create club form validates the name and member cap', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubFormScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('club-save-button')));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên câu lạc bộ'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('club-name-field')),
      'Vmito Tân Bình',
    );
    await tester.enterText(
      find.byKey(const Key('club-max-members-field')),
      '501',
    );
    await tester.tap(find.byKey(const Key('club-save-button')));
    await tester.pump();
    expect(find.text('Nhập số từ 1 đến 500'), findsOneWidget);
  });
}
