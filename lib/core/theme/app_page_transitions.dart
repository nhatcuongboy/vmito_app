import 'package:flutter/cupertino.dart';

/// Keeps horizontal content gestures out of the route's back-swipe edge.
class AppPageTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => super.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (!route.isFirst && !route.fullscreenDialog)
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.paddingOf(
              context,
            ).left.clamp(20, double.infinity),
            child: const AbsorbPointer(child: SizedBox.expand()),
          ),
      ],
    ),
  );
}
