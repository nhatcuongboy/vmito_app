import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class PickedProfileImage {
  const PickedProfileImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

typedef ProfileImagePicker =
    Future<PickedProfileImage?> Function(
      ImageSource source,
    );

class DeviceProfileImagePicker {
  DeviceProfileImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PickedProfileImage?> pick(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (image == null) return null;
    return PickedProfileImage(
      bytes: await image.readAsBytes(),
      filename: image.name,
    );
  }
}

final profileImagePickerProvider = Provider<ProfileImagePicker>(
  (ref) => DeviceProfileImagePicker().pick,
);
