import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/shared/widgets/app_time_picker.dart';

void main() {
  Widget app(ValueChanged<TimeOfDay?> onSelected) => MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('vi')],
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () async => onSelected(
            await showAppTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 18, minute: 30),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );

  testWidgets('shows the initial time and returns the confirmed value', (
    tester,
  ) async {
    TimeOfDay? selected;
    await tester.pumpWidget(app((value) => selected = value));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-time-picker-sheet')), findsOneWidget);
    expect(find.text('18:30'), findsOneWidget);

    final picker = tester.widget<CupertinoDatePicker>(
      find.byKey(const Key('app-time-picker-wheel')),
    );
    picker.onDateTimeChanged(DateTime(2000, 1, 1, 20, 45));
    await tester.pump();
    expect(find.text('20:45'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-time-picker-confirm')));
    await tester.pumpAndSettle();

    expect(selected, const TimeOfDay(hour: 20, minute: 45));
  });

  testWidgets('cancel keeps the caller value unchanged', (tester) async {
    TimeOfDay? selected = const TimeOfDay(hour: 9, minute: 0);
    await tester.pumpWidget(app((value) => selected = value));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-time-picker-cancel')));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
