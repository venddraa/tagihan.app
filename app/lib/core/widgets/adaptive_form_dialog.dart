import 'package:flutter/material.dart';

/// Keeps forms spacious on phones and bounded on desktop windows.
class AdaptiveFormDialog extends StatelessWidget {
  const AdaptiveFormDialog({
    super.key,
    required this.child,
    required this.maxHeight,
  });

  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(child: SafeArea(child: child));
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: maxHeight),
        child: child,
      ),
    );
  }
}
