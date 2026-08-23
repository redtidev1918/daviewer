import 'dart:async';

import 'package:flutter/material.dart';

/// A relative timestamp (e.g. "3 分钟前") that refreshes itself once a minute
/// so it never goes stale while the screen is open.
final class RelativeTimeText extends StatefulWidget {
  const RelativeTimeText({
    required this.time,
    required this.format,
    this.style,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final DateTime? time;

  /// Produces the label from [time] (e.g. `AppStrings.relativeTime`).
  final String Function(DateTime? time) format;

  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<RelativeTimeText> createState() => _RelativeTimeTextState();
}

final class _RelativeTimeTextState extends State<RelativeTimeText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.format(widget.time),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      style: widget.style,
    );
  }
}
