import 'dart:async';
import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/desktop_uri_launcher.dart';
import '../network/dynamic_proxy_dio.dart';
import '../network/proxy_controller.dart';

const _clientId = String.fromEnvironment('DAKIT_CLIENT_ID');

final class AppRuntime {
  AppRuntime({
    required this.clientId,
    required this.oauth,
    required this.transport,
    required this.transfers,
    this.proxyController,
  });

  final String clientId;
  final DAKitOAuthClient? oauth;
  final OfficialApiClient? transport;
  final BackgroundTransferManager transfers;
  final ProxyController? proxyController;

  void Function()? _proxyListener;

  bool get isConfigured => clientId.trim().isNotEmpty;

  factory AppRuntime.fromEnvironment() {
    final profile = _environmentNetworkProfile();
    return _build(profile);
  }

  static Future<AppRuntime> create() async {
    final proxyController = ProxyController();
    await proxyController.start();
    debugPrint(
      'DAViewer proxy: ${proxyController.config?.host}:${proxyController.config?.port ?? '-'}',
    );
    final dio = createDynamicProxyDio(
      () => proxyController.directive,
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final runtime = _build(null, dio: dio, proxyController: proxyController);
    await runtime.transfers.initialize();
    runtime._listenForProxyChanges();
    return runtime;
  }

  static AppRuntime _build(
    NetworkProfile? networkProfile, {
    Dio? dio,
    ProxyController? proxyController,
  }) {
    final clientId = _clientId;
    final transfers = BackgroundTransferManager();
    if (clientId.trim().isEmpty) {
      return AppRuntime(
        clientId: clientId,
        oauth: null,
        transport: null,
        transfers: transfers,
        proxyController: proxyController,
      );
    }

    final oauth = DAKitOAuthClient(
      config: OAuthConfig(
        clientId: clientId,
        redirectUri: Uri.parse('dakit://oauth/callback'),
      ),
      endpoint: dio == null ? null : DioOAuthEndpoint(dio: dio),
      networkProfile: dio == null ? networkProfile : null,
      launcher: const DesktopUriLauncher(),
    );
    final transport = OfficialApiClient(
      session: oauth.session,
      dio: dio,
      networkProfile: dio == null ? networkProfile : null,
      config: ApiConfig(userAgent: 'DAViewer/1.0'),
    );
    return AppRuntime(
      clientId: clientId,
      oauth: oauth,
      transport: transport,
      transfers: transfers,
      proxyController: proxyController,
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
  }

  static NetworkProfile _environmentNetworkProfile() {
    final rawProxy =
        Platform.environment['https_proxy'] ??
        Platform.environment['http_proxy'];
    if (rawProxy == null || rawProxy.trim().isEmpty) {
      return NetworkProfile.environment();
    }
    final uri = Uri.tryParse(rawProxy.trim());
    if (uri == null || uri.host.isEmpty) {
      return NetworkProfile.environment();
    }
    return NetworkProfile.httpProxy(
      proxyServer: HttpProxyServer(
        host: uri.host,
        port: uri.hasPort
            ? uri.port
            : uri.scheme == 'https'
            ? 443
            : 80,
      ),
    );
  }
}
