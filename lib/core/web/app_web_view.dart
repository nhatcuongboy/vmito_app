import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

/// A Vmito page opened in an isolated, in-app browser. [path] must be a
/// relative Vmito path; arbitrary URLs are deliberately not accepted here.
class AppWebPage {
  const AppWebPage({
    required this.path,
    required this.title,
    this.requiresAuth = false,
  });

  final String path;
  final String title;
  final bool requiresAuth;
}

class WebViewSession {
  const WebViewSession({required this.id, required this.code});

  factory WebViewSession.fromJson(Map<String, dynamic> json) => WebViewSession(
    id: json['id']! as String,
    code: json['code']! as String,
  );

  final String id;
  final String code;
}

class WebViewSessionService {
  const WebViewSessionService(this._client);
  final ApiClient _client;

  Future<WebViewSession> create() async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.webViewSessions,
    );
    return unwrap(response.data, WebViewSession.fromJson);
  }

  Future<void> revoke(String id) => _client.post<void>(
    ApiEndpoints.revokeWebViewSession(id),
  );
}

final webViewSessionServiceProvider = Provider<WebViewSessionService>(
  (ref) => WebViewSessionService(ref.read(apiClientProvider)),
);

class _PreparedWebPage {
  const _PreparedWebPage({required this.url, this.sessionId});

  final Uri url;
  final String? sessionId;
}

/// Opens trusted Vmito pages inside the app. Authenticated sessions are
/// bridged through a short-lived code rather than exposing app tokens to URL.
abstract final class AppWebView {
  static Future<void> open(
    BuildContext context,
    ProviderContainer container,
    AppWebPage page,
  ) async {
    try {
      final hasToken = container.read(tokenStorageProvider).hasAccessToken;
      final prepared = await _prepare(
        page,
        hasToken: hasToken,
        service: hasToken
            ? container.read(webViewSessionServiceProvider)
            : null,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AuthenticatedWebViewScreen(
            title: page.title,
            initialUrl: prepared.url,
            sessionId: prepared.sessionId,
          ),
        ),
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open this page. Please try again.'),
          ),
        );
      }
    }
  }

  static Uri _trustedUri(String path) =>
      Uri.parse('${AppConfig.webBaseUrl}$path');

  static Future<_PreparedWebPage> _prepare(
    AppWebPage page, {
    required bool hasToken,
    required WebViewSessionService? service,
  }) async {
    if (!page.path.startsWith('/') || page.path.startsWith('//')) {
      throw ArgumentError.value(page.path, 'path', 'must be a relative path');
    }
    if (page.requiresAuth && !hasToken) {
      throw StateError('This web page requires an authenticated user.');
    }
    if (!hasToken) return _PreparedWebPage(url: _trustedUri(page.path));

    final session = await service!.create();
    return _PreparedWebPage(
      url: buildCallbackUri(page.path, session.code),
      sessionId: session.id,
    );
  }

  /// Builds the localized callback URL while leaving its return path unlocalized.
  /// The web app's next-intl router adds the active locale itself.
  static Uri buildCallbackUri(String path, String code) {
    final base = Uri.parse(AppConfig.webBaseUrl);
    final localePath = path
        .split('/')
        .where((part) => part.isNotEmpty)
        .firstOrNull;
    final locale =
        localePath == 'vi' || localePath == 'en' || localePath == 'cn'
        ? localePath
        : 'vi';
    final returnUrl = path.replaceFirst(RegExp(r'^/(vi|en|cn)(?=/|$)'), '');
    return base.replace(
      path: '/$locale/auth/mobile-callback',
      fragment: Uri(
        queryParameters: {'code': code, 'returnUrl': returnUrl},
      ).query,
    );
  }
}

/// Embeds a Vmito web destination as the current Flutter route rather than
/// pushing another route. This is useful while an entire native screen is
/// temporarily delegated to its web implementation.
class AppWebViewPage extends ConsumerStatefulWidget {
  const AppWebViewPage({required this.page, super.key});

  final AppWebPage page;

  @override
  ConsumerState<AppWebViewPage> createState() => _AppWebViewPageState();
}

class _AppWebViewPageState extends ConsumerState<AppWebViewPage> {
  late Future<_PreparedWebPage> _prepared;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AppWebViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.path != widget.page.path ||
        oldWidget.page.requiresAuth != widget.page.requiresAuth) {
      _load();
    }
  }

  void _load() {
    final hasToken = ref.read(tokenStorageProvider).hasAccessToken;
    _prepared = AppWebView._prepare(
      widget.page,
      hasToken: hasToken,
      service: hasToken ? ref.read(webViewSessionServiceProvider) : null,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_PreparedWebPage>(
    future: _prepared,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.page.title)),
          body: Center(
            child: FilledButton.icon(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        );
      }
      final prepared = snapshot.data;
      if (prepared == null) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.page.title)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return AuthenticatedWebViewScreen(
        title: widget.page.title,
        initialUrl: prepared.url,
        sessionId: prepared.sessionId,
      );
    },
  );
}

class AuthenticatedWebViewScreen extends ConsumerStatefulWidget {
  const AuthenticatedWebViewScreen({
    required this.title,
    required this.initialUrl,
    this.sessionId,
    super.key,
  });
  final String title;
  final Uri initialUrl;
  final String? sessionId;

  @override
  ConsumerState<AuthenticatedWebViewScreen> createState() =>
      _AuthenticatedWebViewScreenState();
}

class _AuthenticatedWebViewScreenState
    extends ConsumerState<AuthenticatedWebViewScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;

  Uri get _origin => Uri.parse(AppConfig.webBaseUrl);
  bool _isTrusted(Uri uri) =>
      uri.scheme == _origin.scheme &&
      uri.host == _origin.host &&
      uri.port == _origin.port;

  @override
  void dispose() {
    final id = widget.sessionId;
    if (id != null) {
      unawaited(
        ref.read(webViewSessionServiceProvider).revoke(id).catchError((_) {}),
      );
    }
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (await _controller?.canGoBack() ?? false) {
      await _controller!.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await _onWillPop() && context.mounted) {
        Navigator.of(context).pop();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
        ],
        bottom: _progress < 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(widget.initialUrl)),
        initialSettings: InAppWebViewSettings(
          incognito: true,
          applicationNameForUserAgent: 'VmitoAppWebView',
          useShouldOverrideUrlLoading: true,
        ),
        onWebViewCreated: (controller) => _controller = controller,
        onProgressChanged: (_, progress) =>
            setState(() => _progress = progress / 100),
        shouldOverrideUrlLoading: (_, action) async {
          final uri = action.request.url?.uriValue;
          if (uri == null || _isTrusted(uri)) {
            return NavigationActionPolicy.ALLOW;
          }
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationActionPolicy.CANCEL;
        },
      ),
    ),
  );
}
