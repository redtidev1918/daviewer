import 'package:dakit_flutter/dakit_flutter.dart';

const _clientId = String.fromEnvironment('DAKIT_CLIENT_ID');

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

  factory AppRuntime.fromEnvironment() {
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
    );
    final transport = OfficialApiClient(
      session: oauth.session,
      config: ApiConfig(userAgent: 'DAViewer/1.0'),
    );
    return AppRuntime(
      clientId: clientId,
      oauth: oauth,
      transport: transport,
      transfers: transfers,
    );
  }
}
