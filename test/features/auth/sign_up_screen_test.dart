import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/auth/presentation/sign_in_screen.dart';
import 'package:vmito_app/features/auth/presentation/sign_up_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _MockAuthService extends Mock implements AuthService {}

Future<void> _pumpSignUp(
  WidgetTester tester, {
  required AuthService service,
  Locale locale = const Locale('vi'),
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [authServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.signUp,
    routes: [
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => SignInScreen(
          registrationCompleted: state.uri.queryParameters['registered'] == '1',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('groups optional sign-up fields under a single hint', (
    tester,
  ) async {
    final service = _MockAuthService();
    await _pumpSignUp(tester, service: service);

    expect(find.text('Thông tin bổ sung (tùy chọn)'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsWidgets);
    expect(find.text('Giới tính'), findsWidgets);
    expect(find.textContaining('Số điện thoại (Tùy chọn)'), findsNothing);
    expect(find.textContaining('Giới tính (Tùy chọn)'), findsNothing);
  });

  testWidgets('rejects a weak password and mismatched confirmation', (
    tester,
  ) async {
    final service = _MockAuthService();
    await _pumpSignUp(tester, service: service);

    await tester.enterText(
      find.byKey(const ValueKey('signup-name-field')),
      'Player',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'player@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'weak',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-confirm-field')),
      'different',
    );
    final submit = find.byKey(const ValueKey('signup-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.textContaining('ít nhất 8 ký tự'), findsOneWidget);
    expect(find.text('Mật khẩu không khớp'), findsOneWidget);
    verifyNever(
      () => service.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
        locale: any(named: 'locale'),
      ),
    );
  });

  testWidgets('registers normalized data and returns to sign-in', (
    tester,
  ) async {
    final service = _MockAuthService();
    when(
      () => service.register(
        email: 'player@example.com',
        password: 'Secret1!',
        name: 'Player',
        locale: 'vi',
      ),
    ).thenAnswer(
      (_) async => const User(
        id: 'user-1',
        email: 'player@example.com',
        role: UserRole.player,
        name: 'Player',
      ),
    );
    await _pumpSignUp(tester, service: service);

    await tester.enterText(
      find.byKey(const ValueKey('signup-name-field')),
      '  Player  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      '  PLAYER@example.com  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'Secret1!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-confirm-field')),
      'Secret1!',
    );
    final submit = find.byKey(const ValueKey('signup-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    verify(
      () => service.register(
        email: 'player@example.com',
        password: 'Secret1!',
        name: 'Player',
        locale: 'vi',
      ),
    ).called(1);
    expect(
      find.text('Đăng ký thành công! Vui lòng đăng nhập để tiếp tục.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Tiếp tục với Google'), findsOneWidget);
  });

  testWidgets(
    'displays localized validation errors when fields are empty (vi)',
    (
      tester,
    ) async {
      final service = _MockAuthService();
      await _pumpSignUp(tester, service: service, locale: const Locale('vi'));

      final submit = find.byKey(const ValueKey('signup-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(find.text('Vui lòng xác nhận mật khẩu'), findsOneWidget);
    },
  );

  testWidgets(
    'displays localized validation errors when fields are empty (en)',
    (
      tester,
    ) async {
      final service = _MockAuthService();
      await _pumpSignUp(tester, service: service, locale: const Locale('en'));

      final submit = find.byKey(const ValueKey('signup-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
    },
  );

  testWidgets('maps 409 ApiException to localized user exists error', (
    tester,
  ) async {
    final service = _MockAuthService();
    when(
      () => service.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
        locale: any(named: 'locale'),
      ),
    ).thenThrow(
      const ApiException(
        message: 'User already exists',
        statusCode: 409,
        kind: ApiErrorKind.unknown,
      ),
    );

    await _pumpSignUp(tester, service: service, locale: const Locale('vi'));

    await tester.enterText(
      find.byKey(const ValueKey('signup-name-field')),
      'Player',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'existing@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'Secret1!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-confirm-field')),
      'Secret1!',
    );
    final submit = find.byKey(const ValueKey('signup-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Email này đã được sử dụng'), findsOneWidget);
  });
}
