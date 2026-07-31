import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/session/data/session_service.dart';
import 'package:vmito_app/features/session/domain/session.dart';

/// The signed-in user's own sessions, newest first.
///
/// Watches the auth controller rather than taking a host id, so signing out
/// empties it and signing in as someone else refetches — a `family` keyed on
/// id would keep the previous host's list cached behind the new one.
///
/// Refresh with `ref.invalidate(hostedSessionsProvider)`.
final hostedSessionsProvider = FutureProvider<Page<Session>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const Page<Session>(
      items: [],
      total: 0,
      page: 1,
      limit: 0,
      totalPages: 0,
    );
  }

  return ref.watch(sessionServiceProvider).hostedBy(user.id, limit: 20);
});
