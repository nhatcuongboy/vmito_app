// The provider's type is whatever `FutureProvider.family` returns; spelling it
// out fights the library's generics and gains nothing.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/session.dart';

/// Manages the access code for unlocking an internal or private session by session ID.
class SessionAccessCodeController extends Notifier<String?> {
  SessionAccessCodeController(this.sessionId);

  final String sessionId;

  @override
  String? build() => null;

  @override
  set state(String? value) => super.state = value;

  void set(String? code) => state = code;
}

/// Access code for unlocking an internal or private session by session ID.
final sessionAccessCodeProvider =
    NotifierProvider.family<SessionAccessCodeController, String?, String>(
  SessionAccessCodeController.new,
);

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
  final code = ref.watch(sessionAccessCodeProvider(sessionId));
  return ref.watch(sessionRepositoryProvider).byId(sessionId, code: code);
});
