// Provider family implementation types are private Riverpod details.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/player_detail.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';

final playerStatisticsProvider =
    FutureProvider.family<List<PlayerStatistics>, String>((ref, sessionId) {
      // Realtime and app-resume already invalidate the session resource. Keep
      // this derived REST resource in lockstep without trusting socket payloads.
      ref.watch(sessionDetailProvider(sessionId));
      return ref.watch(sessionRepositoryProvider).playerStatistics(sessionId);
    });

final playerDetailProvider = FutureProvider.family<PlayerDetail, String>((
  ref,
  playerId,
) {
  return ref.watch(sessionRepositoryProvider).playerById(playerId);
});

final showShuttlecockCountProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(sessionRepositoryProvider).showShuttlecockCount();
  } on Object {
    return false;
  }
});
