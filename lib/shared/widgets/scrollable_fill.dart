import 'package:flutter/material.dart';

/// Wraps a non-scrollable child in a scroll view so pull-to-refresh works even
/// for empty/error states.
final class ScrollableFill extends StatelessWidget {
  const ScrollableFill({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: child,
        ),
      ),
    );
  }
}
