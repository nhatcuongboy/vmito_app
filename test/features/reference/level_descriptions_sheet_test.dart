import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/reference/data/level_description_repository.dart';
import 'package:vmito_app/features/reference/domain/level_description.dart';
import 'package:vmito_app/features/reference/presentation/level_descriptions_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  required List<LevelDescription> descriptions,
}) async {
  tester.view
    ..physicalSize = const Size(1170, 4000)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        levelDescriptionsProvider.overrideWith((ref) async => descriptions),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showLevelDescriptions(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every level from the static table, in rank order', (
    tester,
  ) async {
    await _openSheet(
      tester,
      descriptions: const [
        LevelDescription(level: 9, description: 'Mới cầm vợt'),
        LevelDescription(level: 1, description: 'Đánh được vài đường cơ bản'),
      ],
    );

    expect(find.text('Skill levels'), findsOneWidget);

    // Every level gets a row, not just the two the backend has prose for.
    for (final level in validLevels) {
      expect(
        find.text(levelShortLabel(level)!),
        findsOneWidget,
        reason: 'level $level badge',
      );
    }
    expect(find.text('Mới cầm vợt'), findsOneWidget);
    expect(find.text('Đánh được vài đường cơ bản'), findsOneWidget);
  });

  testWidgets('a level with no prose says so instead of rendering blank', (
    tester,
  ) async {
    await _openSheet(tester, descriptions: const []);

    expect(
      find.text('No description yet'),
      findsNWidgets(validLevels.length),
    );
  });
}
