import 'package:flutter/material.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/create_session_screen.dart';

const _dialogBreakpoint = 768.0;
const _dialogWidth = 720.0;

/// Opens the full session edit form using the presentation that fits the
/// available window: a near-full-height sheet on phones and a constrained
/// dialog on wider windows.
Future<Session?> showSessionEditModal(
  BuildContext context, {
  required Session session,
}) {
  final size = MediaQuery.sizeOf(context);
  final form = CreateSessionScreen(
    key: ValueKey('edit-modal-${session.id}'),
    initialSession: session,
    editingSessionId: session.id,
    modalPresentation: true,
  );

  if (size.width >= _dialogBreakpoint) {
    return showDialog<Session>(
      context: context,
      builder: (context) => Dialog(
        key: const Key('session-edit-dialog'),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: _dialogWidth,
          height: size.height * 0.9,
          child: form,
        ),
      ),
    );
  }

  return showModalBottomSheet<Session>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SizedBox(
      key: const Key('session-edit-bottom-sheet'),
      height: MediaQuery.sizeOf(context).height * 0.96,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: form,
      ),
    ),
  );
}
