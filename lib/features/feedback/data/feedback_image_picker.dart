import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class PickedFeedbackImage {
  const PickedFeedbackImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

typedef FeedbackImagePicker = Future<PickedFeedbackImage?> Function();

class DeviceFeedbackImagePicker {
  DeviceFeedbackImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PickedFeedbackImage?> pick() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    final compressed = await FlutterImageCompress.compressWithList(
      await image.readAsBytes(),
      minWidth: 1600,
      minHeight: 1600,
      quality: 82,
    );
    return PickedFeedbackImage(
      bytes: compressed,
      filename: 'feedback-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }
}

final feedbackImagePickerProvider = Provider<FeedbackImagePicker>(
  (ref) => DeviceFeedbackImagePicker().pick,
);
