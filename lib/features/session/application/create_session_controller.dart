import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/data/session_service.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/session.dart';

/// Creates a session.
///
/// `AsyncValue<Session?>` rather than a bespoke state class: the screen needs
/// exactly idle / submitting / failed / created, and `AsyncValue` already
/// carries all four. `null` data is the idle state.
class CreateSessionController extends Notifier<AsyncValue<Session?>> {
  @override
  AsyncValue<Session?> build() => const AsyncValue.data(null);

  /// Returns the created session, or null when the request failed.
  ///
  /// The error is kept in [state] for the form to render inline, and is not
  /// rethrown: a failed create is an expected outcome of a form, not an
  /// exceptional one.
  Future<Session?> submit(CreateSessionRequest request) async {
    state = const AsyncValue.loading();

    final result = await AsyncValue.guard(
      () => ref.read(sessionServiceProvider).create(request),
    );
    state = result;

    return result.asData?.value;
  }

  Future<Session?> update(String id, CreateSessionRequest request) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(sessionServiceProvider).update(id, request),
    );
    state = result;
    return result.asData?.value;
  }
}

final createSessionControllerProvider =
    NotifierProvider<CreateSessionController, AsyncValue<Session?>>(
      CreateSessionController.new,
    );
