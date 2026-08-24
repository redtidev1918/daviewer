import 'dart:async';
import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';

import '../auth/webview_oauth_bridge.dart';
import '../auth/migrating_auth_stores.dart';
import '../diagnostics/app_logger.dart';
import '../network/dynamic_proxy_dio.dart';
import '../network/proxy_controller.dart';
import '../network/system_proxy.dart';
import '../network/webview_proxy_manager.dart';

/// Public client id baked into the release build so ordinary users don't have
/// to register their own DeviantArt app. A Public OAuth client has no secret,
/// so the client id is safe to ship. Override with
/// `--dart-define=DAKIT_CLIENT_ID=...` during development.
const String _clientId = String.fromEnvironment(
  'DAKIT_CLIENT_ID',
  defaultValue: '75380',
);

final class AppRuntime {
  AppRuntime({
    required this.clientId,
    required this.oauth,
    required this.transport,
    required this.transfers,
    this.proxyController,
    this.dio,
    this.webViewOAuthBridge,
    this.webViewProxyManager,
  });

  final String clientId;
  final DAKitOAuthClient? oauth;
  final OfficialApiClient? transport;
  final BackgroundTransferManager transfers;
  final ProxyController? proxyController;
  final Dio? dio;
  final WebViewOAuthBridge? webViewOAuthBridge;
  final WebViewProxyManager? webViewProxyManager;

  void Function()? _proxyListener;

  bool get isConfigured => clientId.trim().isNotEmpty;

  factory AppRuntime.fromEnvironment() {
    final profile = _environmentNetworkProfile();
    return _build(profile);
  }

  static Future<AppRuntime> create() async {
    final logger = AppLogger.instance;
    final proxyController = ProxyController();
    await proxyController.start();
    logger.info(
      'runtime',
      'proxy: ${proxyController.config?.host}:${proxyController.config?.port ?? '-'}',
    );
    final dio = createDynamicProxyDio(
      () => proxyController.directive,
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final runtime = _build(null, dio: dio, proxyController: proxyController);
    await runtime.webViewProxyManager?.prepare();
    await runtime.transfers.initialize();
    runtime._listenForProxyChanges();
    return runtime;
  }

  static AppRuntime _build(
    NetworkProfile? networkProfile, {
    Dio? dio,
    ProxyController? proxyController,
  }) {
    final logger = AppLogger.instance;
    final clientId = _clientId;
    final transfers = BackgroundTransferManager(diagnostics: logger);
    if (clientId.trim().isEmpty) {
      logger.warning('runtime', 'DAKIT_CLIENT_ID not set; app is unconfigured');
      return AppRuntime(
        clientId: clientId,
        oauth: null,
        transport: null,
        transfers: transfers,
        proxyController: proxyController,
        dio: dio,
      );
    }

    final webViewOAuthBridge = WebViewOAuthBridge();
    final webViewProxyManager = proxyController == null
        ? null
        : WebViewProxyManager(proxyController);
    final oauth = DAKitOAuthClient(
      config: OAuthConfig(
        clientId: clientId,
        redirectUri: Uri.parse('dakit://oauth/callback'),
        scopes: const <String>{
          OAuthScope.basic,
          OAuthScope.browse,
          OAuthScope.collection,
          OAuthScope.user,
          OAuthScope.userManage,
          OAuthScope.gallery,
          OAuthScope.feed,
          OAuthScope.message,
        },
      ),
      endpoint: dio == null ? null : DioOAuthEndpoint(dio: dio),
      networkProfile: dio == null ? networkProfile : null,
      // Use a DAViewer-named Keychain item on macOS so the system's
      // "…wants to use confidential information stored in …" prompt shows the
      // product name instead of the plugin default
      // "flutter_secure_storage_service" (which reads like an arbitrary secret
      // being exfiltrated). Only DAViewer's own OAuth tokens are stored there.
      tokenStore: MigratingTokenStore(
        primary: SecureTokenStore(
          storage: clientSecureStorage(serviceName: 'DAViewer'),
        ),
        legacy: SecureTokenStore(),
      ),
      pendingStore: MigratingPendingAuthorizationStore(
        primary: SecurePendingAuthorizationStore(
          storage: clientSecureStorage(serviceName: 'DAViewer'),
        ),
        legacy: SecurePendingAuthorizationStore(),
      ),
      launcher: webViewOAuthBridge,
      callbacks: MergedCallbackUriSource(
        initial: AppLinksCallbackUriSource(),
        others: <CallbackUriSource>[webViewOAuthBridge.callbacks],
      ),
      diagnostics: logger,
    );
    final transport = OfficialApiClient(
      session: oauth.session,
      dio: dio,
      networkProfile: dio == null ? networkProfile : null,
      config: ApiConfig(userAgent: 'DAViewer/1.0'),
      diagnostics: logger,
    );
    return AppRuntime(
      clientId: clientId,
      oauth: oauth,
      transport: transport,
      transfers: transfers,
      proxyController: proxyController,
      dio: dio,
      webViewOAuthBridge: webViewOAuthBridge,
      webViewProxyManager: webViewProxyManager,
    );
  }

  void _listenForProxyChanges() {
    final proxyController = this.proxyController;
    if (proxyController == null) return;
    _proxyListener = () {
      final config = proxyController.config;
      unawaited(
        transfers.configureProxy(
          config == null
              ? null
              : ProxyConfiguration(host: config.host, port: config.port),
        ),
      );
      // Android/macOS proxy overrides are process-wide. Windows environments
      // are prepared immediately and reused by every WebView in the app.
      final manager = webViewProxyManager;
      if (manager != null) {
        unawaited(manager.prepare().then<void>((_) {}));
      }
    };
    proxyController.addListener(_proxyListener!);
    _proxyListener!();
  }

  void dispose() {
    final proxyController = this.proxyController;
    final listener = _proxyListener;
    if (proxyController != null && listener != null) {
      proxyController.removeListener(listener);
    }
    proxyController?.dispose();
    unawaited(webViewProxyManager?.dispose() ?? Future<void>.value());
    unawaited(webViewOAuthBridge?.dispose() ?? Future<void>.value());
  }

  static NetworkProfile _environmentNetworkProfile() {
    SystemProxyConfig? proxy;
    for (final name in const <String>[
      'https_proxy',
      'HTTPS_PROXY',
      'http_proxy',
      'HTTP_PROXY',
      'all_proxy',
      'ALL_PROXY',
    ]) {
      final raw = Platform.environment[name];
      if (raw == null || raw.trim().isEmpty) continue;
      proxy = parseProxyAddress(raw);
      if (proxy != null) break;
    }
    if (proxy == null) {
      return NetworkProfile.environment();
    }
    return NetworkProfile.httpProxy(
      proxyServer: HttpProxyServer(host: proxy.host, port: proxy.port),
    );
  }
}
