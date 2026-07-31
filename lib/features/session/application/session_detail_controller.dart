// The provider's type is whatever `FutureProvider.family` returns; spelling it
// out fights the library's generics and gains nothing.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/data/session_service.dart';
import 'package:vmito_app/features/session/domain/session.dart';

/// Loads one session by id.
///
/// A `family` keyed on the id, so two detail screens on the navigation stack
/// keep separate state and neither clobbers the other.
///
/// A `FutureProvider` rather than a hand-rolled state class: this screen has
/// one resource and no pagination, unlike the browse list.
///
/// Refresh with `ref.invalidate(sessionDetailProvider(id))` — from
/// pull-to-refresh, and later from the app-resume handler, since a
/// backgrounded socket may have missed events (see docs/REALTIME.md).
final sessionDetailProvider = FutureProvider.family<Session, String>((
  ref,
  sessionId,
) {
  return ref.watch(sessionServiceProvider).byId(sessionId);
});
