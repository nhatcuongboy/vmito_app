import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/post_composer_draft.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_composer_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  Widget buildSubject(
    Future<void> Function(PostComposerDraft draft) onSubmit,
  ) => ProviderScope(
    child: MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PostComposerSheet(userName: 'An', onSubmit: onSubmit),
    ),
  );

  testWidgets('requires content before enabling publish', (tester) async {
    var submitted = false;
    await tester.pumpWidget(
      buildSubject((_) async {
        submitted = true;
      }),
    );

    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('post-composer-submit')),
    );
    expect(submit.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('post-content-field')),
      'Bài viết mới',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('post-composer-submit')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('post-composer-submit')));
    await tester.pump();
    expect(submitted, isTrue);
  });

  testWidgets('asks before discarding a populated draft', (tester) async {
    await tester.pumpWidget(buildSubject((_) async {}));
    await tester.enterText(find.byKey(const Key('post-content-field')), 'Nháp');
    await tester.pump();

    await tester.tap(find.byKey(const Key('post-composer-close')));
    await tester.pumpAndSettle();

    expect(find.text('Bỏ bài viết?'), findsOneWidget);
    expect(find.text('Tiếp tục chỉnh sửa'), findsOneWidget);
  });
}
