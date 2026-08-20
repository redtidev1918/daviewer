import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/app_logger.dart';

/// Shows the current session's log tail and error summary.
final class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

final class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String _logTail = '（暂无日志）';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() => _loading = true);
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
          _logTail = '（暂无日志文件）';
          _loading = false;
        });
        return;
      }
      final lines = await target.readAsLines();
      final tail = lines.length <= 120 ? lines : lines.sublist(lines.length - 120);
      setState(() {
        _logTail = tail.join('\n');
        _loading = false;
      });
    } on Object catch (error) {
      setState(() {
        _logTail = '读取日志失败：$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logger = AppLogger.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志与诊断'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
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
                      ? '本次运行无错误'
                      : '本次运行记录到 ${logger.errorCount} 个错误',
                ),
                const Spacer(),
                Text(
                  '日志目录：\n${logger.logsDirectory}',
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
                    style: const TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
