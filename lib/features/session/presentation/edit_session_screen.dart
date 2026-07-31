import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/application/session_detail_controller.dart';
import 'package:vmito_app/features/session/presentation/create_session_screen.dart';

class EditSessionScreen extends ConsumerWidget {
  const EditSessionScreen({
    required this.sessionId,
    this.isClone = false,
    super.key,
  });

  final String sessionId;
  final bool isClone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionDetailProvider(sessionId));
    return session.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(sessionDetailProvider(sessionId)),
        ),
      ),
      data: (value) => CreateSessionScreen(
        key: ValueKey('${isClone ? 'clone' : 'edit'}-$sessionId'),
        initialSession: value,
        editingSessionId: isClone ? null : sessionId,
        isClone: isClone,
      ),
    );
  }
}
