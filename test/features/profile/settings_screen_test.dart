import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/profile/presentation/settings_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Widget _destination(String label) => Scaffold(
  appBar: AppBar(),
  body: Center(child: Text(label)),
);

Widget _app({
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) {
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
      GoRoute(
        path: AppRoutes.editProfile,
        name: AppRoutes.nameEditProfile,
        builder: (_, _) => _destination('Edit profile destination'),
      ),
      GoRoute(
        path: AppRoutes.accountSecurity,
        name: AppRoutes.nameAccountSecurity,
        builder: (_, _) => _destination('Account security destination'),
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      locale: const Locale('vi'),
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
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

  testWidgets('opens the profile editing screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-edit-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile destination'), findsOneWidget);
  });

  testWidgets('opens the account security screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.text('Tài khoản và bảo mật'));
    await tester.pumpAndSettle();
    expect(find.text('Account security destination'), findsOneWidget);
  });

  testWidgets('shows compact current values and grouped cards', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Theo hệ thống'), findsOneWidget);
    expect(find.text('Đang hiển thị địa chỉ mới'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(3));
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

  testWidgets('does not overflow on narrow and wide layouts', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (
        size: const Size(320, 700),
        brightness: Brightness.light,
        textScaler: const TextScaler.linear(1.5),
      ),
      (
        size: const Size(900, 900),
        brightness: Brightness.dark,
        textScaler: TextScaler.noScaling,
      ),
    ]) {
      tester.view.physicalSize = configuration.size;
      await tester.pumpWidget(
        _app(
          brightness: configuration.brightness,
          textScaler: configuration.textScaler,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
