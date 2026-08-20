import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';

final class ArtworkDetailPage extends StatefulWidget {
  const ArtworkDetailPage({
    required this.artworkId,
    required this.transport,
    super.key,
  });

  final String artworkId;
  final OfficialApiClient transport;

  @override
  State<ArtworkDetailPage> createState() => _ArtworkDetailPageState();
}

final class _ArtworkDetailPageState extends State<ArtworkDetailPage> {
  Artwork? _artwork;
  MediaAsset? _original;
  Object? _error;
  bool _loading = true;
  bool _downloading = false;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final artwork = await OfficialArtworkRepository(
        widget.transport,
      ).getById(widget.artworkId);
      final original = await OfficialMediaRepository(
        widget.transport,
      ).originalFile(widget.artworkId);
      if (!mounted) return;
      setState(() {
        _artwork = artwork;
        _original = original;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    final original = _original;
    if (original == null || !original.canTransfer || _downloading) return;
    setState(() => _downloading = true);
    try {
      final client = HttpClient();
      final request = await client.getUrl(original.uri!);
      final response = await request.close();
      final directory = Directory(
        '${Platform.environment['HOME'] ?? '.'}/Downloads/DAViewer',
      );
      await directory.create(recursive: true);
      final filename = original.filename ??
          original.uri!.pathSegments.lastOrNull ??
          'original.bin';
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      final sink = file.openWrite();
      await response.pipe(sink);
      await sink.flush();
      await sink.close();
      client.close();
      if (!mounted) return;
      setState(() => _savedPath = file.path);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artwork = _artwork;
    final original = _original;
    return Scaffold(
      appBar: AppBar(title: Text(artwork?.title ?? 'Artwork detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('$_error'))
          : artwork == null
          ? const Center(child: Text('Artwork not found.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (artwork.media.isNotEmpty)
                  Image.network(
                    artwork.media.first.uri.toString(),
                    errorBuilder: (_, _, _) => const Icon(Icons.image),
                  ),
                const SizedBox(height: 16),
                Text(artwork.title, style: Theme.of(context).textTheme.headlineSmall),
                Text('by ${artwork.author.username}'),
                const SizedBox(height: 16),
                Text(
                  'Original: ${original?.availability.name ?? 'unknown'}',
                ),
                if (original?.mimeType != null)
                  Text('MIME: ${original!.mimeType}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: original?.canTransfer == true && !_downloading
                      ? _download
                      : null,
                  child: _downloading
                      ? const CircularProgressIndicator()
                      : const Text('Download original'),
                ),
                if (_savedPath != null) Text('Saved to $_savedPath'),
              ],
            ),
    );
  }
}
