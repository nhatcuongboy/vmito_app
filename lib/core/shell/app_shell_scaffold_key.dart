import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The `GlobalKey` for `AppShell`'s `Scaffold`, the one the `SlideOutMenu`
/// drawer is attached to.
///
/// Each tab screen builds its own nested `Scaffold`, so `Scaffold.of(context)`
/// called from a tab's `AppBar` resolves to that nested instance, not the
/// shell's — reading this key is the only way to reach the shell's drawer
/// from inside a tab.
///
/// Every app-shell instance overrides this provider with its own state-owned
/// key.
/// The fallback keeps menu buttons safe on root routes that can sit above the
/// shell (for example a public profile route).
final _fallbackScaffoldKey = GlobalKey<ScaffoldState>();

final appShellScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>(
  (ref) => _fallbackScaffoldKey,
);
