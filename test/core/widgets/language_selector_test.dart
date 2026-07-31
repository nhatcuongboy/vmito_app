import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _MemoryLocaleRepository implements LocaleRepository {
  String? languageCode;

  @override
  String? readLanguageCode() => languageCode;

  @override
  Future<void> writeLanguageCode(String languageCode) async {
    this.languageCode = languageCode;
  }
}

class _LocalizedHarness extends ConsumerWidget {
  const _LocalizedHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      locale: ref.watch(localeControllerProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            appBar: AppBar(actions: const [LanguageButton()]),
            body: Center(child: Text(l10n.homeTitle)),
          );
        },
      ),
    );
  }
}

void main() {
  testWidgets('changes language immediately and persists the selection', (
    tester,
  ) async {
    final repository = _MemoryLocaleRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeRepositoryProvider.overrideWithValue(repository),
        ],
        child: const _LocalizedHarness(),
      ),
    );

    expect(find.text('Trang chủ'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.language_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Tiếng Anh'), findsOneWidget);
    expect(find.text('Tiếng Trung'), findsOneWidget);

    await tester.tap(find.text('Tiếng Anh'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(repository.languageCode, 'en');
  });
}
