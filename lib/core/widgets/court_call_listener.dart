import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/notifications/court_call_effects.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/widgets/court_call_dialog.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart';

class CourtCallListener extends ConsumerStatefulWidget {
  const CourtCallListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CourtCallListener> createState() => _CourtCallListenerState();
}

class _CourtCallListenerState extends ConsumerState<CourtCallListener> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final Set<String> _handled = {};
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    final socket = ref.read(socketClientProvider)..connect();
    _subscription = socket.on(SessionEvent.playersSelected).listen(_onEvent);
    final effects = ref.read(courtCallEffectsProvider);
    unawaited(effects.initialize());
  }

  Future<void> _onEvent(Map<String, dynamic> payload) async {
    final call = CourtCall.tryParse(payload);
    final user = ref.read(currentUserProvider);
    if (!mounted || call == null || user == null || call.userId != user.id) {
      return;
    }
    if (!_handled.add(call.fingerprint)) return;
    Timer(const Duration(minutes: 5), () => _handled.remove(call.fingerprint));

    final l10n = AppLocalizations.of(context);
    final message = l10n.courtCallAnnouncement(call.courtNumber);
    final courtDisplayName =
        call.courtName ?? l10n.courtNumber(call.courtNumber);
    final route = AppRoutes.liveSession(call.sessionId);
    final effects = ref.read(courtCallEffectsProvider);
    unawaited(
      effects.notify(
        title: l10n.courtCallTitle,
        message: message,
        payload: route,
      ),
    );
    unawaited(effects.speak(message, l10n.localeName));

    if (_dialogOpen) return;
    _dialogOpen = true;
    // Socket events land mid-frame; pushing a dialog route right away can
    // race the semantics tree and trip a framework assertion. Wait for the
    // frame to settle first.
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) {
      _dialogOpen = false;
      return;
    }
    await CourtCallDialog.show(
      context,
      courtDisplayName: courtDisplayName,
      onAcknowledge: () => context.go(route),
    );
    _dialogOpen = false;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
