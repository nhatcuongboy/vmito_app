import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets a tab's root content handle a second tap on its navigation item.
class TabReselectionController {
  final _actions = <int, _TabReselectionAction>{};
  var _nextId = 0;

  /// Registers the currently visible root scrollable for [tabIndex].
  ///
  /// The returned callback is safe to call after a newer widget has replaced
  /// this registration.
  VoidCallback register({
    required int tabIndex,
    required Future<void> Function() onReselect,
  }) {
    final id = _nextId++;
    _actions[tabIndex] = _TabReselectionAction(id, onReselect);
    return () {
      if (_actions[tabIndex]?.id == id) _actions.remove(tabIndex);
    };
  }

  Future<void> handleReselect(int tabIndex) async {
    await _actions[tabIndex]?.callback();
  }
}

class _TabReselectionAction {
  const _TabReselectionAction(this.id, this.callback);

  final int id;
  final Future<void> Function() callback;
}

final tabReselectionControllerProvider = Provider<TabReselectionController>(
  (ref) => TabReselectionController(),
);

Future<void> scrollToTop(ScrollController controller) async {
  if (!controller.hasClients || controller.offset <= 0) return;
  await controller.animateTo(
    0,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );
}
