import 'package:vmito_app/bootstrap.dart';

/// Entry point. Everything of substance is in `bootstrap.dart` so that
/// integration tests and future flavor entry points can reuse the same setup.
void main() => runGuarded(bootstrap);
