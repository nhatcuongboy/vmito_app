import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_fee_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('fee screen renders config and validates a negative amount', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(430, 1400)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clubFeeProvider.overrideWith(
            (ref, period) async => const ClubFeeConfig(
              maleFeeMonthly: 500000,
              femaleFeePerSession: 70000,
            ),
          ),
          clubMembersProvider.overrideWith(
            (ref, id) async => const [
              ClubMember(
                id: 'm1',
                userId: 'u1',
                name: 'Lan',
                email: 'lan@example.com',
                role: 'MEMBER',
              ),
            ],
          ),
          clubMonthlyMembersProvider.overrideWith(
            (ref, period) async => const [],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubFeeScreen(clubId: 'club-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cấu hình phí'), findsOneWidget);
    expect(find.text('Phí theo tháng'), findsOneWidget);
    expect(find.byKey(const Key('club-fee-member')), findsOneWidget);

    final field = find.byKey(const Key('club-fee-malePerSession'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '-1');
    await tester.ensureVisible(find.byKey(const Key('club-fee-save')));
    await tester.tap(find.byKey(const Key('club-fee-save')));
    await tester.pump();

    expect(find.text('Phí phải là số không âm'), findsOneWidget);
  });
}
