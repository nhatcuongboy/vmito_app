import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/notifications/court_call_effects.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/router/app_router.dart' show rootNavigatorKey;
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/widgets/court_call_dialog.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Listens for the [SessionEvent.playersSelected] socket event and calls the
/// player to their court — TTS, local notification, and [CourtCallDialog].
///
/// This widget lives in `MaterialApp.router`'s `builder`, which sits *above*
/// the app's `Router`/`Navigator` in the element tree (a well-known
/// `MaterialApp.builder` gotcha — see the Flutter source for
/// `WidgetsApp.build`: `builder` wraps the already-built router widget as a
/// child, it does not sit inside it). That means this widget's own
/// [BuildContext] has no `Navigator`/`GoRouter` ancestor to find, regardless
/// of which screen is currently showing — `showDialog(context: context)` or
/// `context.go(...)` from here fails silently every time (the TTS/notify
/// calls above already fired, which is why only the sound plays). We use
/// [rootNavigatorKey]'s context instead, since that key is attached to
/// GoRouter's own root `Navigator` and is always inside the routed tree.
class CourtCallListener extends ConsumerStatefulWidget {
  const CourtCallListener({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
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

    // The dialog's context (see the class doc); this widget's own `context`
    // has no Navigator to show it on.
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) return;

    final l10n = AppLocalizations.of(dialogContext);
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
    try {
      // Kicked off now so it overlaps the frame wait below rather than
      // adding to it; a slow/failed fetch just means the dialog shows
      // without the extra context, never a delay past the timeout.
      final sessionFuture = _resolveSession(call.sessionId);
      // Socket events land mid-frame; pushing a dialog route right away can
      // race the semantics tree and trip a framework assertion. Wait for the
      // frame to settle first.
      await SchedulerBinding.instance.endOfFrame;
      final session = await sessionFuture;
      final dialogContextAfterFetch = rootNavigatorKey.currentContext;
      if (!mounted ||
          dialogContextAfterFetch == null ||
          !dialogContextAfterFetch.mounted) {
        return;
      }
      final showNewAddress = ref
          .read(locationPreferencesControllerProvider)
          .showNewAddress;
      await CourtCallDialog.show(
        dialogContextAfterFetch,
        courtDisplayName: courtDisplayName,
        sessionName: session?.name,
        venueAddress: session != null && session.hasLocation
            ? session.displayPlace(showNewAddress: showNewAddress)
            : null,
        hostName: session?.hostName ?? session?.host?.name,
        onAcknowledge: () => widget.router.go(route),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  /// Reads the already-cached [sessionDetailProvider] first — warm whenever
  /// the player has this session open anywhere, including the live session
  /// screen that a `players_selected` refetch also targets — and only hits
  /// the network as a fallback, capped so a slow/offline request never holds
  /// up the call itself.
  Future<Session?> _resolveSession(String sessionId) async {
    final cached = switch (ref.read(sessionDetailProvider(sessionId))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (cached != null) return cached;
    try {
      return await ref
          .read(sessionDetailProvider(sessionId).future)
          .timeout(const Duration(seconds: 2));
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
