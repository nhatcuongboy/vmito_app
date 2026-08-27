import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

// Injectable for tests that cannot rasterize through a production GPU.
// ignore: one_member_abstracts
abstract interface class AchievementCaptureService {
  Future<Uint8List?> capture(RenderRepaintBoundary boundary);
}

class RepaintBoundaryAchievementCaptureService
    implements AchievementCaptureService {
  const RepaintBoundaryAchievementCaptureService();

  @override
  Future<Uint8List?> capture(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

// Injectable so widget tests never open the platform share sheet.
// ignore: one_member_abstracts
abstract interface class AchievementShareService {
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    Rect? origin,
  });
}

class SharePlusAchievementService implements AchievementShareService {
  const SharePlusAchievementService();

  @override
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    Rect? origin,
  }) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
      sharePositionOrigin: origin,
    ),
  );
}

final achievementCaptureServiceProvider = Provider<AchievementCaptureService>(
  (ref) => const RepaintBoundaryAchievementCaptureService(),
);

final achievementShareServiceProvider = Provider<AchievementShareService>(
  (ref) => const SharePlusAchievementService(),
);
