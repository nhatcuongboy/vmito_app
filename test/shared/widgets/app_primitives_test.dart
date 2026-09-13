import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
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

  testWidgets('AppConfirmDialog renders submit type with primary styling', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      buildSubject(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showAppConfirmDialog(
                context,
                title: 'Start Session',
                content: 'Do you want to start?',
                confirmLabel: 'Start',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Start Session'), findsOneWidget);
    expect(find.text('Do you want to start?'), findsOneWidget);
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    // Submit type does not override backgroundColor with error
    expect(confirmButton.style?.backgroundColor, isNull);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets(
    'AppConfirmDialog renders destructive type with error background',
    (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        buildSubject(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context,
                  type: AppConfirmDialogType.destructive,
                  title: 'Sign Out',
                  content: 'Are you sure?',
                  confirmLabel: 'Sign Out',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Sign Out'), findsNWidgets(2)); // Title and button
      final confirmButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign Out'),
      );
      final context = tester.element(find.byType(AppConfirmDialog));
      final expectedErrorColor = Theme.of(context).colorScheme.error;
      expect(
        confirmButton.style?.backgroundColor?.resolve({}),
        expectedErrorColor,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    },
  );

  test('AppTheme configures roomier dialog sizing on mobile', () {
    expect(
      AppTheme.light.dialogTheme.insetPadding,
      const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
    );
  });

  test('AppTheme uses muted text for unfocused input hints and labels', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final inputTheme = theme.inputDecorationTheme;
      final labelStyle = WidgetStateProperty.resolveAs<TextStyle?>(
        inputTheme.labelStyle,
        <WidgetState>{},
      );

      expect(
        inputTheme.hintStyle?.color,
        theme.extension<AppPalette>()!.mutedForeground,
      );
      expect(inputTheme.hintStyle?.fontSize, 14);
      expect(inputTheme.hintStyle?.height, closeTo(20 / 14, 0.0001));
      expect(
        labelStyle?.color,
        theme.extension<AppPalette>()!.mutedForeground,
      );
    }
  });

  test('AppTheme distinguishes selected navigation destinations', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final navigationTheme = theme.navigationBarTheme;
      final selectedStates = <WidgetState>{WidgetState.selected};
      final unselectedStates = <WidgetState>{};
      final selectedIcon = navigationTheme.iconTheme?.resolve(selectedStates);
      final unselectedIcon = navigationTheme.iconTheme?.resolve(
        unselectedStates,
      );
      final selectedLabel = navigationTheme.labelTextStyle?.resolve(
        selectedStates,
      );
      final unselectedLabel = navigationTheme.labelTextStyle?.resolve(
        unselectedStates,
      );

      expect(navigationTheme.height, AppSizes.bottomNavHeight);
      expect(selectedIcon?.size, 24);
      expect(unselectedIcon?.size, 24);
      expect(selectedIcon?.color, theme.colorScheme.primary);
      expect(
        unselectedIcon?.color,
        theme.extension<AppPalette>()!.mutedForeground,
      );
      expect(selectedLabel?.color, theme.colorScheme.primary);
      expect(selectedLabel?.fontWeight, FontWeight.w600);
      expect(unselectedLabel?.fontWeight, FontWeight.w400);
    }
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
