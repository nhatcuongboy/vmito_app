import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

import '../../support/fake_secure_storage.dart';

class _MockAuthService extends Mock implements AuthService {}

Future<ProviderContainer> _pumpDialog(
  WidgetTester tester,
  AuthService service,
) async {
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(service),
      tokenStorageProvider.overrideWithValue(
        TokenStorage(FakeSecureStorage()),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDeleteAccountDialog(context),
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
  return container;
}

void main() {
  group('delete account dialog', () {
    testWidgets('states what is removed AND what is retained', (tester) async {
      // Consent to an irreversible action is only meaningful if the user knows
      // hosted sessions and payment history survive, anonymized.
      await _pumpDialog(tester, _MockAuthService());

      expect(find.text('Xoá tài khoản'), findsWidgets);
      expect(find.textContaining('không thể hoàn tác'), findsOneWidget);
      expect(find.textContaining('Sẽ bị xoá'), findsOneWidget);
      expect(find.textContaining('giữ ẩn danh'), findsOneWidget);
      expect(find.textContaining('không thể đăng nhập lại'), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      final service = _MockAuthService();
      await _pumpDialog(tester, service);

      // Found by role, not by copy: the cancel action is the dialog's only
      // TextButton, so re-wording it must not break this test.
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      verifyNever(service.deleteAccount);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('confirming calls the backend and signs out', (tester) async {
      final service = _MockAuthService();
      when(service.deleteAccount).thenAnswer((_) async {});

      final container = await _pumpDialog(tester, service);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      verify(service.deleteAccount).called(1);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a backend refusal keeps the dialog open and reports it', (
      tester,
    ) async {
      final service = _MockAuthService();
      when(service.deleteAccount).thenThrow(
        const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Cannot delete the last admin account',
          statusCode: 400,
        ),
      );

      final container = await _pumpDialog(tester, service);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // The account still exists, so the user must not be signed out — that
      // would look like success.
      expect(find.text('Cannot delete the last admin account'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        container.read(authControllerProvider).status,
        isNot(AuthStatus.unauthenticated),
      );
    });
  });
}
