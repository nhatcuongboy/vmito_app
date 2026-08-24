import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/legal/presentation/legal_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Widget _app(String initialLocation, {Locale locale = const Locale('vi')}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.terms,
        builder: (_, _) => const LegalScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (_, _) => const LegalScreen(document: LegalDocument.privacy),
      ),
    ],
  );
  return MaterialApp.router(
    locale: locale,
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets('privacy deep link selects privacy and changes route by tab', (
    tester,
  ) async {
    await tester.pumpWidget(_app(AppRoutes.privacy));
    await tester.pumpAndSettle();

    expect(find.text('Chính sách bảo mật'), findsWidgets);
    expect(find.text('1. Thông tin chúng tôi thu thập'), findsOneWidget);

    await tester.tap(find.text('Điều khoản dịch vụ').first);
    await tester.pumpAndSettle();
    expect(find.text('1. Chấp nhận điều khoản'), findsOneWidget);
  });

  testWidgets('renders canonical English legal copy', (tester) async {
    await tester.pumpWidget(
      _app(AppRoutes.terms, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Last updated: July 26, 2026'), findsOneWidget);
    expect(find.text('1. Acceptance of Terms'), findsOneWidget);
  });
}
