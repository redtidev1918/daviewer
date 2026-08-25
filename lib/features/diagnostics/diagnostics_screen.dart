import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/app_logger.dart';
import '../../core/l10n/app_strings.dart';

/// Shows the current session's log tail and error summary.
final class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

final class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String _logTail = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() => _loading = true);
    final s = strings(ref.read(appLanguageProvider));
    try {
      final dir = Directory(AppLogger.instance.logsDirectory);
      final files = await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList()
          .then((list) => list..sort((a, b) => b.path.compareTo(a.path)));
      final target = files.isEmpty ? null : files.first;
      if (target == null) {
        setState(() {
          _logTail = s.noLogFile;
          _loading = false;
        });
        return;
      }
      final lines = await target.readAsLines();
      final tail = lines.length <= 120
          ? lines
          : lines.sublist(lines.length - 120);
      setState(() {
        _logTail = tail.join('\n');
        _loading = false;
      });
    } on Object catch (error) {
      setState(() {
        _logTail = s.logReadFailed(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logger = AppLogger.instance;
    final s = strings(ref.watch(appLanguageProvider));
    return Scaffold(
      appBar: AppBar(
        title: Text(s.diagnostics),
        actions: <Widget>[
          IconButton(
            tooltip: s.refresh,
            onPressed: _loadLog,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Icon(
                  logger.errorCount == 0
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: logger.errorCount == 0
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  logger.errorCount == 0
                      ? s.noErrorsThisRun
                      : s.errorsThisRun(logger.errorCount),
                ),
                const Spacer(),
                Text(
                  s.logDirectory(logger.logsDisplayName),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SelectableText(
                    _logTail,
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
                  ),
          ),
        ],
      ),
    );
  }
}
