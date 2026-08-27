import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/profile/application/profile_controller.dart';
import 'package:vmito_app/features/profile/domain/form/profile_form.dart';
import 'package:vmito_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _user = User(
  id: 'user-1',
  email: 'player@example.test',
  name: 'Nguyễn Văn A',
  phone: '0912345678',
  gender: 'MALE',
  level: 5,
  levelDescription: 'Đánh phong trào',
  role: UserRole.player,
);

class _FakeProfileController extends ProfileController {
  ProfileDraft? submitted;

  @override
  ProfileMutationState build() => const ProfileMutationState();

  @override
  Future<bool> updateProfile(String userId, ProfileDraft draft) async {
    submitted = draft;
    // Keep the test screen mounted so the submitted draft can be inspected.
    return false;
  }
}

void main() {
  testWidgets('loads fields, blocks an empty name, and submits a valid draft', (
    tester,
  ) async {
    final controller = _FakeProfileController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_user),
          profileDetailsProvider(
            'user-1',
          ).overrideWith((ref) async => _user),
          profileControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EditProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('player@example.test'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      '',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-save-button')),
    );
    await tester.tap(find.byKey(const ValueKey('profile-save-button')));
    await tester.pump();
    expect(controller.submitted, isNull);
    expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      '  Tên mới  ',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-save-button')),
    );
    await tester.tap(find.byKey(const ValueKey('profile-save-button')));
    await tester.pump();
    expect(controller.submitted?.name, 'Tên mới');
  });

  testWidgets('does not overflow at phone and wide widths', (tester) async {
    for (final size in [const Size(375, 812), const Size(900, 900)]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_user),
            profileDetailsProvider(
              'user-1',
            ).overrideWith((ref) async => _user),
          ],
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });
}
