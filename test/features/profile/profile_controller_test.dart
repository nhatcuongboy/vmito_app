import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/profile/application/profile_controller.dart';
import 'package:vmito_app/features/profile/data/profile_image_picker.dart';
import 'package:vmito_app/features/profile/data/profile_service.dart';
import 'package:vmito_app/features/profile/domain/form/profile_form.dart';

class _MockProfileService extends Mock implements ProfileService {}

class _MockAuthService extends Mock implements AuthService {}

const _user = User(
  id: 'user-1',
  email: 'player@example.test',
  name: 'Player',
  role: UserRole.player,
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  test('updates auth state and suppresses duplicate profile saves', () async {
    final service = _MockProfileService();
    final completion = Completer<User>();
    when(
      () => service.updateUser('user-1', any()),
    ).thenAnswer((_) => completion.future);
    final container = ProviderContainer(
      overrides: [profileServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    const draft = ProfileDraft(name: 'Updated');
    final controller = container.read(profileControllerProvider.notifier);

    final first = controller.updateProfile('user-1', draft);
    final duplicate = await controller.updateProfile('user-1', draft);
    expect(duplicate, isFalse);
    verify(() => service.updateUser('user-1', draft.toJson())).called(1);

    completion.complete(_user.copyWith(name: 'Updated'));
    expect(await first, isTrue);
    expect(
      container.read(authControllerProvider).user?.name,
      'Updated',
    );
  });

  test(
    'uploads an avatar, persists its identifiers, and clears progress',
    () async {
      final service = _MockProfileService();
      when(
        () => service.uploadAvatar(
          any(),
          filename: any(named: 'filename'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final progress =
            invocation.namedArguments[#onProgress]!
                as void Function(int progress);
        progress(60);
        return const ProfileImageAsset(
          url: 'https://example.test/avatar.jpg',
          publicId: 'avatars/user-1',
        );
      });
      when(
        () => service.updateUser('user-1', any()),
      ).thenAnswer(
        (_) async => _user.copyWith(
          image: 'https://example.test/avatar.jpg',
          imagePublicId: 'avatars/user-1',
        ),
      );
      final container = ProviderContainer(
        overrides: [profileServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(profileControllerProvider.notifier)
          .uploadAvatar(
            'user-1',
            PickedProfileImage(
              bytes: Uint8List.fromList([1, 2, 3]),
              filename: 'avatar.png',
            ),
          );

      expect(success, isTrue);
      expect(container.read(profileControllerProvider).avatarProgress, isNull);
      final payload =
          verify(
                () => service.updateUser('user-1', captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(payload, {
        'image': 'https://example.test/avatar.jpg',
        'imagePublicId': 'avatars/user-1',
      });
    },
  );

  test('change-password controller uses the secure auth endpoint', () async {
    final service = _MockAuthService();
    when(
      () => service.changePassword(
        currentPassword: 'Current1!',
        newPassword: 'Secret1!',
      ),
    ).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(changePasswordControllerProvider.notifier)
        .submit(currentPassword: 'Current1!', newPassword: 'Secret1!');

    expect(success, isTrue);
    verify(
      () => service.changePassword(
        currentPassword: 'Current1!',
        newPassword: 'Secret1!',
      ),
    ).called(1);
  });
}
