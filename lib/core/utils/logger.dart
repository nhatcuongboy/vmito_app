import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:vmito_app/core/config/app_config.dart';

/// Single logging entry point. Never use `print` or `debugPrint` directly —
/// this one is silenced in release builds and can be pointed at Crashlytics
/// from one place later.
abstract final class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5),
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  static void debug(String message) => _logger.d(message);

  static void info(String message) => _logger.i(message);

  static void warn(String message, {Object? error}) =>
      _logger.w(message, error: error);

  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  /// Network chatter, gated separately so it can be turned off without
  /// silencing everything else.
  static void network(String message, {Object? error}) {
    if (!AppConfig.enableNetworkLogs) return;
    _logger.d('[net] $message${error == null ? '' : '\n$error'}');
  }
}
