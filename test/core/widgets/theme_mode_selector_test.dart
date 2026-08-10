import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/core/widgets/theme_mode_selector.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _MemoryThemeRepository implements ThemeRepository {
  String? themeModeName;

  @override
  String? readThemeModeName() => themeModeName;

  @override
  Future<void> writeThemeModeName(String themeModeName) async {
    this.themeModeName = themeModeName;
  }
}

class _ThemedHarness extends ConsumerWidget {
  const _ThemedHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeControllerProvider),
      home: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(AppIcons.dark),
                  onPressed: () => showThemeModeSelector(context),
                ),
              ],
            ),
            body: Center(
              child: Text(Theme.of(context).brightness.name),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  testWidgets('changes theme immediately and persists the selection', (
    tester,
  ) async {
    final repository = _MemoryThemeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeRepositoryProvider.overrideWithValue(repository)],
        child: const _ThemedHarness(),
      ),
    );

    expect(find.text('light'), findsOneWidget);
    await tester.tap(find.byIcon(AppIcons.dark));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);
    expect(repository.themeModeName, 'dark');
  });
}
