import 'package:flutter/material.dart';

/// Detects a rightward swipe that starts at the left edge of the screen.
///
/// This is kept above the app's navigators so it can provide the same back
/// gesture on every route, while leaving regular horizontal content gestures
/// untouched unless they start at the edge and travel predominantly right.
class AppEdgeBackGesture extends StatefulWidget {
  const AppEdgeBackGesture({
    required this.onBack,
    required this.child,
    super.key,
    this.edgeWidth = 32,
    this.triggerDistance = 80,
    this.touchSlop = 18,
  });

  final VoidCallback onBack;
  final Widget child;
  final double edgeWidth;
  final double triggerDistance;
  final double touchSlop;

  @override
  State<AppEdgeBackGesture> createState() => _AppEdgeBackGestureState();
}

class _AppEdgeBackGestureState extends State<AppEdgeBackGesture> {
  int? _activePointer;
  Offset? _startPosition;
  bool? _isHorizontal;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _handlePointerDown,
    onPointerMove: _handlePointerMove,
    onPointerUp: _handlePointerUp,
    onPointerCancel: _reset,
    child: widget.child,
  );

  void _handlePointerDown(PointerDownEvent event) {
    if (event.position.dx > widget.edgeWidth) return;

    _activePointer = event.pointer;
    _startPosition = event.position;
    _isHorizontal = null;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _isHorizontal != null) return;

    final delta = event.position - _startPosition!;
    if (delta.distance < widget.touchSlop) return;
    _isHorizontal = delta.dx.abs() >= delta.dy.abs();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;

    final delta = event.position - _startPosition!;
    final isRightwardSwipe =
        (_isHorizontal ?? (delta.dx.abs() >= delta.dy.abs())) &&
        delta.dx >= widget.triggerDistance;

    _reset(event);
    if (isRightwardSwipe) widget.onBack();
  }

  void _reset([PointerEvent? _]) {
    _activePointer = null;
    _startPosition = null;
    _isHorizontal = null;
  }
}
