import 'package:flutter/material.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: icon,
    title: title,
    content: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 320),
      child: content,
    ),
    actions: actions,
  );
}
