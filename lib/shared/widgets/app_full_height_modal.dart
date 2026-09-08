import 'package:flutter/material.dart';

/// Opens the standard tall mobile modal used for form-heavy flows.
///
/// The sheet remains draggable through the modal route. A caller can opt into
/// clipping when it needs a custom surface shape.
Future<T?> showAppFullHeightModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double heightFactor = 1,
  bool useRootNavigator = false,
  BorderRadiusGeometry? borderRadius,
}) {
  assert(
    heightFactor > 0 && heightFactor <= 1,
    'heightFactor must be between 0 (exclusive) and 1 (inclusive).',
  );

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: borderRadius == null ? null : Colors.transparent,
    builder: (context) {
      final child = builder(context);
      return FractionallySizedBox(
        heightFactor: heightFactor,
        child: borderRadius == null
            ? child
            : ClipRRect(borderRadius: borderRadius, child: child),
      );
    },
  );
}
