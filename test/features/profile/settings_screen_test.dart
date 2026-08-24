import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/profile/presentation/settings_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Widget _destination(String label) => Scaffold(
  appBar: AppBar(),
  body: Center(child: Text(label)),
);

Widget _app() {
  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.nameSettings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        name: AppRoutes.nameFeedback,
        builder: (_, _) => _destination('Feedback destination'),
      ),
      GoRoute(
        path: AppRoutes.terms,
        name: AppRoutes.nameTerms,
        builder: (_, _) => _destination('Legal destination'),
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      locale: const Locale('vi'),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('opens feedback destination', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.text('Trợ giúp và phản hồi'));
    await tester.pumpAndSettle();
    expect(find.text('Feedback destination'), findsOneWidget);
  });

  testWidgets('opens legal destination', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.ensureVisible(find.text('Điều khoản và chính sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Điều khoản và chính sách'));
    await tester.pumpAndSettle();
    expect(find.text('Legal destination'), findsOneWidget);
  });

  testWidgets('opens and closes About Vmito dialog', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.ensureVisible(find.text('Về Vmito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Về Vmito'));
    await tester.pumpAndSettle();

    expect(find.text('Tác giả: Nhật Cường'), findsOneWidget);
    expect(find.text('0914810765'), findsOneWidget);
    expect(find.text('admin@vmito.com'), findsOneWidget);
    expect(find.text('Fanpage'), findsOneWidget);
    expect(find.text('Zalo'), findsOneWidget);
    expect(find.text('Messenger'), findsOneWidget);

    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Tác giả: Nhật Cường'), findsNothing);
  });
}
