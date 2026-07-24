import 'package:flutter/widgets.dart';

import '../theme/layout.dart';

/// Constrains a page body to a centered, readable column on wider windows so
/// content doesn't stretch edge-to-edge on desktop/web. On compact (phone)
/// windows it is a pure passthrough — the mobile layout is unchanged.
///
/// Drop it around the scrolling body of a screen (typically the child of
/// `SafeArea`), e.g.
///
/// ```dart
/// SafeArea(
///   child: AdaptivePageBody(
///     child: ListView(...),
///   ),
/// )
/// ```
class AdaptivePageBody extends StatelessWidget {
  const AdaptivePageBody({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.readable,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) return child;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
