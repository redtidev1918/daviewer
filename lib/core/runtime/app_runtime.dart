import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';

import '../network/system_proxy.dart';

const _clientId = String.fromEnvironment('DAKIT_CLIENT_ID');
const _proxyUrl = String.fromEnvironment('DAKIT_PROXY_URL');

final class AppRuntime {
  AppRuntime({
    required this.clientId,
    required this.oauth,
    required this.transport,
    required this.transfers,
  });

  final String clientId;
  final DAKitOAuthClient? oauth;
  final OfficialApiClient? transport;
  final BackgroundTransferManager transfers;

  bool get isConfigured => clientId.trim().isNotEmpty;

  factory AppRuntime.fromEnvironment() => _build(_environmentNetworkProfile());

  static Future<AppRuntime> create() async {
    final systemProxy = await detectSystemProxy();
    final networkProfile = systemProxy == null
        ? _environmentNetworkProfile()
        : NetworkProfile.httpProxy(
            proxyServer: HttpProxyServer(
              host: systemProxy.host,
              port: systemProxy.port,
            ),
          );
    return _build(networkProfile);
  }

  static AppRuntime _build(NetworkProfile networkProfile) {
    final clientId = _clientId;
    final transfers = BackgroundTransferManager();
    if (clientId.trim().isEmpty) {
      return AppRuntime(
        clientId: clientId,
        oauth: null,
        transport: null,
        transfers: transfers,
      );
    }

    final oauth = DAKitOAuthClient(
      config: OAuthConfig(
        clientId: clientId,
        redirectUri: Uri.parse('dakit://oauth/callback'),
      ),
      networkProfile: networkProfile,
    );
    final transport = OfficialApiClient(
      session: oauth.session,
      config: ApiConfig(userAgent: 'DAViewer/1.0'),
      networkProfile: networkProfile,
    );
    return AppRuntime(
      clientId: clientId,
      oauth: oauth,
      transport: transport,
      transfers: transfers,
    );
  }

  static NetworkProfile _environmentNetworkProfile() {
    final rawProxy = _proxyUrl.trim().isNotEmpty
        ? _proxyUrl
        : Platform.environment['https_proxy'] ??
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
