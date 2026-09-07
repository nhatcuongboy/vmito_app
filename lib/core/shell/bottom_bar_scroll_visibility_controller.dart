import 'dart:async';

import 'package:flutter/material.dart';

/// Decides whether a bottom bar should be visible from descendant scrolls.
///
/// Hide-on-scroll is active only when the scrollable's content overflows its
/// viewport by more than [minimumOverflow]. Direction changes must accumulate
/// [directionThreshold] logical pixels before changing [value].
class BottomBarScrollVisibilityController extends ValueNotifier<bool> {
  BottomBarScrollVisibilityController({
    this.minimumOverflow = 150,
    this.directionThreshold = 24,
    this.bottomTolerance = 1,
    this.accumulationResetDelay = const Duration(milliseconds: 180),
  }) : assert(minimumOverflow >= 0, 'minimumOverflow cannot be negative'),
       assert(directionThreshold > 0, 'directionThreshold must be positive'),
       assert(bottomTolerance >= 0, 'bottomTolerance cannot be negative'),
       super(true);

  final double minimumOverflow;
  final double directionThreshold;
  final double bottomTolerance;
  final Duration accumulationResetDelay;

  bool _keyboardVisible = false;
  bool _hideOnScrollEnabled = false;
  double _accumulatedDelta = 0;
  BuildContext? _activeScrollContext;
  Timer? _accumulationResetTimer;

  /// Whether the most recently observed scrollable is tall enough to enable
  /// hide-on-scroll behavior.
  bool get isEnabled => !_keyboardVisible && _hideOnScrollEnabled;

  ScrollMetrics? _lastMetrics;

  void show() {
    _resetAccumulation();
    value = true;
  }

  /// Restores the initial state when the shell changes tab/page ownership.
  void reset() {
    _activeScrollContext = null;
    _lastMetrics = null;
    _hideOnScrollEnabled = false;
    show();
  }

  /// Suspends hide-on-scroll while the soft keyboard changes the viewport.
  ///
  /// Opening the keyboard also restores the bar without waiting for another
  /// gesture. After it closes, a fresh threshold-sized drag is required.
  void updateKeyboardVisibility({required bool isVisible}) {
    if (_keyboardVisible == isVisible) return;
    _keyboardVisible = isVisible;
    show();
    if (!isVisible) _updateEligibility(_lastMetrics);
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollStartNotification) {
      _selectScrollSource(notification.context);
    } else if (_activeScrollContext == null &&
        notification is ScrollUpdateNotification) {
      _selectScrollSource(notification.context);
    } else if (!identical(notification.context, _activeScrollContext)) {
      return false;
    }

    _lastMetrics = notification.metrics;
    _updateEligibility(notification.metrics);
    if (!isEnabled) {
      show();
      return false;
    }

    // Both boundaries are stable navigation states. Check them before
    // direction handling so reaching the top, pull-to-refresh overscroll, and
    // the final downward update at the bottom always reveal the bar.
    if (_isAtScrollBoundary(notification.metrics)) {
      show();
      return false;
    }

    if (notification is ScrollStartNotification) {
      final continuesRecentInput = _accumulationResetTimer?.isActive ?? false;
      _accumulationResetTimer?.cancel();
      _accumulationResetTimer = null;
      if (!continuesRecentInput) _accumulatedDelta = 0;
      return false;
    }

    if (notification is ScrollEndNotification) {
      _scheduleAccumulationReset();
      return false;
    }

    if (notification is! ScrollUpdateNotification) return false;

    // Use the actual scroll delta instead of requiring dragDetails. Trackpad,
    // mouse-wheel, fling, and some CustomScrollView updates legitimately have
    // no DragUpdateDetails but are still scrolling the page.
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;
    _accumulationResetTimer?.cancel();
    _accumulationResetTimer = null;

    final changedDirection =
        _accumulatedDelta != 0 &&
        _accumulatedDelta.isNegative != delta.isNegative;
    _accumulatedDelta = changedDirection ? delta : _accumulatedDelta + delta;

    if (_accumulatedDelta.abs() < directionThreshold) return false;

    // Positive scroll deltas move toward later content (a downward page
    // scroll), while negative deltas move back toward the top.
    value = _accumulatedDelta.isNegative;
    _accumulatedDelta = 0;
    return false;
  }

  /// Handles content/viewport size changes even when no scroll gesture occurs.
  bool handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_activeScrollContext == null ||
        !identical(notification.context, _activeScrollContext)) {
      return false;
    }

    _lastMetrics = notification.metrics;
    _updateEligibility(notification.metrics);
    if (!isEnabled || _isAtScrollBoundary(notification.metrics)) {
      show();
    }
    return false;
  }

  @override
  void dispose() {
    _accumulationResetTimer?.cancel();
    super.dispose();
  }

  void _selectScrollSource(BuildContext? context) {
    if (identical(context, _activeScrollContext)) return;
    _activeScrollContext = context;
    _lastMetrics = null;
    _hideOnScrollEnabled = false;
    _resetAccumulation();
  }

  void _scheduleAccumulationReset() {
    _accumulationResetTimer?.cancel();
    _accumulationResetTimer = Timer(
      accumulationResetDelay,
      _resetAccumulation,
    );
  }

  void _resetAccumulation() {
    _accumulationResetTimer?.cancel();
    _accumulationResetTimer = null;
    _accumulatedDelta = 0;
  }

  bool _isAtScrollBoundary(ScrollMetrics metrics) =>
      metrics.extentBefore <= bottomTolerance ||
      metrics.extentAfter <= bottomTolerance;

  void _updateEligibility(ScrollMetrics? metrics) {
    if (metrics == null) {
      _hideOnScrollEnabled = false;
      return;
    }
    final scrollRange = metrics.maxScrollExtent - metrics.minScrollExtent;
    if (!scrollRange.isFinite) {
      _hideOnScrollEnabled = false;
      return;
    }

    if (scrollRange > minimumOverflow) {
      _hideOnScrollEnabled = true;
    } else if (value || scrollRange <= 0) {
      // While hidden, collapsing the bar expands the viewport and reduces the
      // reported scroll range by the bar's height. Keep the prior eligibility
      // until the bar is visible again so content near the cutoff cannot
      // oscillate between hidden and visible during its own animation.
      _hideOnScrollEnabled = false;
    }
  }
}
