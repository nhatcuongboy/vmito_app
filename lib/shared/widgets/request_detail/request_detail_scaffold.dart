import 'package:flutter/material.dart';

/// The shell every "join request" detail screen sits in — session or club.
/// Just an [AppBar] over a scrollable body; the sticky approve/reject bar (if
/// any) is part of [body] itself so it can react to the same async state the
/// body renders from, rather than being wired up separately.
class RequestDetailScaffold extends StatelessWidget {
  const RequestDetailScaffold({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: body,
  );
}
