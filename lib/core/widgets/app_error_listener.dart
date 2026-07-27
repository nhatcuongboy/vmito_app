import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';

/// Renders unhandled API failures as SnackBars.
///
/// This is where the web app's global `toaster` call from the axios
/// interceptor ends up. It sits directly under `MaterialApp.builder` so it has
/// a `ScaffoldMessenger` above it and stays mounted across navigation.
class AppErrorListener extends ConsumerStatefulWidget {
  const AppErrorListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppErrorListener> createState() => _AppErrorListenerState();
}

class _AppErrorListenerState extends ConsumerState<AppErrorListener> {
  StreamSubscription<ApiException>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(apiErrorBusProvider).stream.listen(_showError);
  }

  void _showError(ApiException error) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
