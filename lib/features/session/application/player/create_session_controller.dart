import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/bulk_create_session.dart';
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

  /// Starts each create/edit form with a clean submit state.
  ///
  /// The controller outlives routes, so without this a reopened edit modal
  /// could immediately render the previous attempt's server error.
  void reset() => state = const AsyncValue.data(null);

  /// Returns the created session, or null when the request failed.
  ///
  /// The error is kept in [state] for the form to render inline, and is not
  /// rethrown: a failed create is an expected outcome of a form, not an
  /// exceptional one.
  Future<Session?> submit(CreateSessionRequest request) async {
    state = const AsyncValue.loading();

    final result = await AsyncValue.guard(
      () => ref.read(sessionRepositoryProvider).create(request),
    );
    state = result;

    return result.asData?.value;
  }

  Future<Session?> update(String id, CreateSessionRequest request) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(sessionRepositoryProvider).update(id, request),
    );
    state = result;
    return result.asData?.value;
  }

  Future<BulkCreateSessionResult?> submitBulk(
    BulkCreateSessionRequest request,
  ) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(sessionRepositoryProvider).createBulk(request),
    );

    if (result case AsyncData(
      value: final bulk,
    ) when bulk.sessions.length > 1 && request.baseSession.images.isNotEmpty) {
      final base = request.baseSession;
      final sync = await AsyncValue.guard(
        () => Future.wait([
          for (final session in bulk.sessions.skip(1))
            ref
                .read(sessionRepositoryProvider)
                .updateImages(
                  session.id,
                  coverPhoto: base.coverPhoto,
                  coverPhotoPublicId: base.coverPhotoPublicId,
                  images: base.images,
                  imagePublicIds: base.imagePublicIds,
                ),
        ]),
      );
      if (sync.hasError) {
        state = AsyncValue.error(sync.error!, sync.stackTrace!);
        return null;
      }
    }

    state = switch (result) {
      AsyncData(value: final bulk) => AsyncValue.data(
        bulk.sessions.isEmpty ? null : bulk.sessions.first,
      ),
      AsyncError(:final error, :final stackTrace) => AsyncValue.error(
        error,
        stackTrace,
      ),
      _ => const AsyncValue.loading(),
    };
    return result.asData?.value;
  }
}

final createSessionControllerProvider =
    NotifierProvider<CreateSessionController, AsyncValue<Session?>>(
      CreateSessionController.new,
    );
