/// Build-time configuration, supplied via `--dart-define`.
///
/// Nothing here is read from a `.env` file: `String.fromEnvironment` is a
/// compile-time constant, which keeps the values out of runtime lookups and
/// lets the tree shaker fold flavor branches away.
///
/// Run with:
/// ```sh
/// flutter run --dart-define-from-file=env/staging.json
/// ```
library;

enum AppFlavor { dev, staging, production }

abstract final class AppConfig {
  static const String _flavorName = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  static AppFlavor get flavor => switch (_flavorName) {
    'production' => AppFlavor.production,
    'staging' => AppFlavor.staging,
    _ => AppFlavor.dev,
  };

  static bool get isProduction => flavor == AppFlavor.production;
  static bool get isDev => flavor == AppFlavor.dev;

  /// REST base URL, including the `/api` suffix.
  ///
  /// Mirrors `NEXT_PUBLIC_API_URL` in vmito-fe. On Android the emulator
  /// reaches the host machine at 10.0.2.2, not localhost.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );

  /// Socket.IO origin — the REST base URL with `/api` stripped.
  ///
  /// The backend serves Socket.IO at the root path and separates concerns by
  /// namespace (`/sessions`, `/tournaments`), so the `/api` prefix must go.
  static String get socketBaseUrl => apiBaseUrl.endsWith('/api')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 4)
      : apiBaseUrl;

  /// Origin of the web app — used for share links and OAuth redirects.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://vmito.com',
  );

  /// Custom scheme registered on both platforms for `flutter_web_auth_2`.
  /// Must match the backend's OAuth redirect allowlist entry.
  static const String authCallbackScheme = String.fromEnvironment(
    'AUTH_CALLBACK_SCHEME',
    defaultValue: 'vmito',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Verbose dio/socket logging. Off in production regardless of the define.
  static bool get enableNetworkLogs => !isProduction;
}
