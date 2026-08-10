import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

// The interface is intentionally injectable so widget tests never open the
// platform share sheet.
// ignore: one_member_abstracts
abstract interface class PlayerStatisticsShareService {
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    Rect? origin,
  });
}

class SharePlusPlayerStatisticsService implements PlayerStatisticsShareService {
  const SharePlusPlayerStatisticsService();

  @override
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    Rect? origin,
  }) => SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'image/png', name: fileName),
      ],
      sharePositionOrigin: origin,
    ),
  );
}

final playerStatisticsShareServiceProvider =
    Provider<PlayerStatisticsShareService>(
      (ref) => const SharePlusPlayerStatisticsService(),
    );

// Separating rasterisation from sharing keeps platform/GPU work injectable in
// widget tests while production still captures the real RepaintBoundary.
// ignore: one_member_abstracts
abstract interface class PlayerStatisticsCaptureService {
  Future<Uint8List?> capture(RenderRepaintBoundary boundary);
}

class RepaintBoundaryStatisticsCaptureService
    implements PlayerStatisticsCaptureService {
  const RepaintBoundaryStatisticsCaptureService();

  @override
  Future<Uint8List?> capture(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

final playerStatisticsCaptureServiceProvider =
    Provider<PlayerStatisticsCaptureService>(
      (ref) => const RepaintBoundaryStatisticsCaptureService(),
    );
