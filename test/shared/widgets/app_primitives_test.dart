import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/shared/widgets/app_button.dart';
import 'package:vmito_app/shared/widgets/app_card.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_app/shared/widgets/app_text_field.dart';

void main() {
  Widget buildSubject(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets('AppButton renders and invokes its callback', (tester) async {
    var wasPressed = false;

    await tester.pumpWidget(
      buildSubject(
        AppButton(label: 'Submit', onPressed: () => wasPressed = true),
      ),
    );

    await tester.tap(find.text('Submit'));
    expect(wasPressed, isTrue);
  });

  testWidgets('AppTextField delegates input and AppCard uses Card', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const AppCard(
          child: AppTextField(decoration: InputDecoration(labelText: 'Name')),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Vmito');
    expect(find.text('Vmito'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('AppDialog renders supplied slots', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const AppDialog(
          title: Text('Title'),
          content: Text('Content'),
          actions: [TextButton(onPressed: null, child: Text('Close'))],
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  test('AppTheme configures roomier dialog sizing on mobile', () {
    expect(
      AppTheme.light.dialogTheme.insetPadding,
      const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
    );
  });

  testWidgets('form labels show the correct marker and semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const Column(
          children: [
            AppRequiredLabel('Name'),
            AppOptionalLabel('Phone', optionalText: 'Optional'),
          ],
        ),
      ),
    );

    expect(find.text('Name *'), findsOneWidget);
    expect(find.text('Phone (Optional)'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(AppRequiredLabel)),
      matchesSemantics(label: 'Name, required'),
    );
    expect(
      tester.getSemantics(find.byType(AppOptionalLabel)),
      matchesSemantics(label: 'Phone, Optional'),
    );
  });
}
