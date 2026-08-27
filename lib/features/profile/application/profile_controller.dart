import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/profile/data/profile_image_picker.dart';
import 'package:vmito_app/features/profile/data/profile_service.dart';
import 'package:vmito_app/features/profile/domain/form/profile_form.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';

class ProfileMutationState {
  const ProfileMutationState({
    this.isSaving = false,
    this.avatarProgress,
    this.coverProgress,
    this.error,
  });

  final bool isSaving;
  final int? avatarProgress;
  final int? coverProgress;
  final Object? error;
}

class ProfileController extends Notifier<ProfileMutationState> {
  @override
  ProfileMutationState build() => const ProfileMutationState();

  ProfileService get _service => ref.read(profileServiceProvider);

  Future<bool> updateProfile(String userId, ProfileDraft draft) async {
    if (state.isSaving) return false;
    state = ProfileMutationState(
      isSaving: true,
      avatarProgress: state.avatarProgress,
      coverProgress: state.coverProgress,
    );
    try {
      final user = await _service.updateUser(userId, draft.toJson());
      _syncUser(user);
      state = ProfileMutationState(
        avatarProgress: state.avatarProgress,
        coverProgress: state.coverProgress,
      );
      return true;
    } on Object catch (error) {
      state = ProfileMutationState(
        avatarProgress: state.avatarProgress,
        coverProgress: state.coverProgress,
        error: error,
      );
      return false;
    }
  }

  Future<bool> uploadAvatar(String userId, PickedProfileImage image) =>
      _upload(userId, image, avatar: true);

  Future<bool> uploadCover(String userId, PickedProfileImage image) =>
      _upload(userId, image, avatar: false);

  Future<bool> _upload(
    String userId,
    PickedProfileImage image, {
    required bool avatar,
  }) async {
    if (avatar ? state.avatarProgress != null : state.coverProgress != null) {
      return false;
    }
    _setProgress(avatar: avatar, progress: 0);
    try {
      final asset = avatar
          ? await _service.uploadAvatar(
              image.bytes,
              filename: image.filename,
              onProgress: (value) => _setProgress(
                avatar: true,
                progress: value,
              ),
            )
          : await _service.uploadCover(
              image.bytes,
              filename: image.filename,
              onProgress: (value) => _setProgress(
                avatar: false,
                progress: value,
              ),
            );
      final user = await _service.updateUser(userId, {
        if (avatar) ...{
          'image': asset.url,
          'imagePublicId': asset.publicId,
        } else ...{
          'coverPhoto': asset.url,
          'coverPhotoPublicId': asset.publicId,
        },
      });
      _syncUser(user);
      _setProgress(avatar: avatar, progress: null);
      return true;
    } on Object catch (error) {
      _setProgress(avatar: avatar, progress: null, error: error);
      return false;
    }
  }

  void _setProgress({
    required bool avatar,
    required int? progress,
    Object? error,
  }) {
    state = ProfileMutationState(
      isSaving: state.isSaving,
      avatarProgress: avatar ? progress : state.avatarProgress,
      coverProgress: avatar ? state.coverProgress : progress,
      error: error,
    );
  }

  void _syncUser(User user) {
    ref.read(authControllerProvider.notifier).setUser(user);
    ref
      ..invalidate(publicUserProvider(user.id))
      ..invalidate(publicProfileProvider(user.id))
      ..invalidate(profileDetailsProvider(user.id));
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileMutationState>(
      ProfileController.new,
    );

// Riverpod intentionally keeps the concrete family implementation private.
// ignore: specify_nonobvious_property_types
final profileDetailsProvider = FutureProvider.family<User, String>(
  (ref, userId) => ref.watch(profileServiceProvider).user(userId),
);

class ChangePasswordState {
  const ChangePasswordState({this.isSaving = false, this.error});

  final bool isSaving;
  final Object? error;
}

class ChangePasswordController extends Notifier<ChangePasswordState> {
  @override
  ChangePasswordState build() => const ChangePasswordState();

  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.isSaving) return false;
    state = const ChangePasswordState(isSaving: true);
    try {
      await ref
          .read(authServiceProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = const ChangePasswordState();
      return true;
    } on Object catch (error) {
      state = ChangePasswordState(error: error);
      return false;
    }
  }
}

final changePasswordControllerProvider =
    NotifierProvider<ChangePasswordController, ChangePasswordState>(
      ChangePasswordController.new,
    );
