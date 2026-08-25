import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/social/presentation/club_form_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('create club form validates the name', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubFormScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('club-save-button')));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên nhóm'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('club-name-field')),
      'Vmito Tân Bình',
    );
  });

  testWidgets('renders the full mobile create form and admin host control', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            const User(
              id: 'admin-1',
              email: 'admin@vmito.test',
              name: 'Admin',
              role: UserRole.admin,
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubFormScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('club-host-user-button')), findsOneWidget);
    expect(find.byKey(const Key('club-all-levels')), findsOneWidget);
    expect(find.text('Hình ảnh nhóm'), findsOneWidget);
    expect(find.text('Sân hoạt động'), findsOneWidget);
    expect(find.text('Mạng xã hội & Liên kết'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('club-add-venue')));
    await tester.tap(find.byKey(const Key('club-add-venue')));
    await tester.pump();
    expect(find.text('Sân 1'), findsOneWidget);
    expect(find.text('Chọn sân'), findsOneWidget);
  });
}
