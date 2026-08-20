import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';

import 'artwork_detail_page.dart';

const _clientId = String.fromEnvironment('DAKIT_CLIENT_ID');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeviantArtClientApp());
}

final class DeviantArtClientApp extends StatelessWidget {
  const DeviantArtClientApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff4263eb)),
      useMaterial3: true,
    ),
    home: const ClientHome(),
  );
}

final class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

final class _ClientHomeState extends State<ClientHome> {
  DAKitOAuthClient? _oauth;
  OfficialApiClient? _transport;
  UserProfile? _account;
  List<Artwork> _artworks = const <Artwork>[];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_clientId.trim().isEmpty) {
      setState(() {
        _error = 'Pass DAKIT_CLIENT_ID at build time.';
        _loading = false;
      });
      return;
    }

    final oauth = DAKitOAuthClient(
      config: OAuthConfig(
        clientId: _clientId,
        redirectUri: Uri.parse('dakit://oauth/callback'),
      ),
    );
    final transport = OfficialApiClient(
      session: oauth.session,
      config: ApiConfig(userAgent: 'DeviantArtClient/0.1'),
    );
    _oauth = oauth;
    _transport = transport;

    try {
      await oauth.resumePending(waitForCallback: false);
      await oauth.validTokens(forceRefresh: false);
      await _loadContent();
    } on DAKitException catch (error) {
      if (error.code != 'oauth.session.missing') {
        setState(() => _error = error);
      }
    } catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final oauth = _oauth;
    if (oauth == null || oauth.isAuthorizing) return;
    setState(() => _loading = true);
    try {
      await oauth.authorize();
      await _loadContent();
    } catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContent() async {
    final transport = _transport;
    if (transport == null) return;
    final account = await OfficialAccountRepository(transport).currentUser();
    final home = await OfficialArtworkRepository(
      transport,
    ).browse(const PageRequest(limit: 24));
    if (!mounted) return;
    setState(() {
      _account = account;
      _artworks = home.items;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DeviantArt Client'),
        actions: <Widget>[
          if (account != null)
            IconButton(
              onPressed: _loading ? null : _loadContent,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('$_error'))
          : account == null
          ? Center(
              child: FilledButton(
                onPressed: _login,
                child: const Text('Login with DeviantArt'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Signed in as ${account.username}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _artworks.length,
                    itemBuilder: (context, index) {
                      final artwork = _artworks[index];
                      return ListTile(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => ArtworkDetailPage(
                              artworkId: artwork.id,
                              transport: _transport!,
                            ),
                          ),
                        ),
                        leading: artwork.media.isNotEmpty
                            ? Image.network(
                                artwork.media.first.uri.toString(),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.image),
                              )
                            : const Icon(Icons.image),
                        title: Text(artwork.title),
                        subtitle: Text(artwork.author.username),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
