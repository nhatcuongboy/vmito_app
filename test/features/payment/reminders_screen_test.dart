import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/payment/application/payment_reminders_controller.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/payment/presentation/reminders_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('renders RemindersScreen with tabs and cards', (tester) async {
    final creatorReminders = [
      PaymentReminder(
        id: 'rem-1',
        type: PaymentReminderType.custom,
        amount: 100000,
        note: 'Tiền sân thứ 6',
        reminderCount: 1,
        lastRemindedAt: DateTime.utc(2026, 8, 30, 10),
        recipient: const PaymentReminderUser(
          id: 'u-2',
          name: 'Player Bob',
        ),
      ),
    ];

    final recipientReminders = [
      PaymentReminder(
        id: 'rem-2',
        amount: 80000,
        reminderCount: 1,
        lastRemindedAt: DateTime.utc(2026, 8, 30, 11),
        creator: const PaymentReminderUser(
          id: 'u-1',
          name: 'Host Alice',
        ),
      ),
    ];

    const hostUser = User(
      id: 'u-1',
      name: 'Host Alice',
      email: 'alice@vmito.com',
      role: UserRole.host,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(hostUser),
          remindersListProvider(
            'creator',
          ).overrideWith((ref) async => creatorReminders),
          remindersListProvider(
            'recipient',
          ).overrideWith((ref) async => recipientReminders),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RemindersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Tabs
    expect(find.text('Nhắc thanh toán'), findsOneWidget);
    expect(find.text('Cần thu'), findsOneWidget);
    expect(find.text('Cần trả'), findsOneWidget);

    // Verify FAB for Host
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Tạo lời nhắc'), findsOneWidget);

    // Verify Creator card in "Cần thu" tab
    expect(find.text('Player Bob'), findsOneWidget);
    expect(find.text('Tiền sân thứ 6'), findsOneWidget);
    expect(find.text('Nhắc lại'), findsOneWidget);
    expect(find.text('Đánh dấu đã thu'), findsOneWidget);

    // Switch to "Cần trả" tab
    await tester.tap(find.text('Cần trả'));
    await tester.pumpAndSettle();

    // Verify Recipient card in "Cần trả" tab
    expect(find.text('Host Alice'), findsOneWidget);
    expect(find.text('Đánh dấu đã trả'), findsOneWidget);
  });

  testWidgets('renders empty state when reminders list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remindersListProvider('creator').overrideWith((ref) async => []),
          remindersListProvider('recipient').overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RemindersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Không có khoản nào cần thu'), findsOneWidget);

    await tester.tap(find.text('Cần trả'));
    await tester.pumpAndSettle();

    expect(find.text('Không có khoản nào cần trả'), findsOneWidget);
  });
}
