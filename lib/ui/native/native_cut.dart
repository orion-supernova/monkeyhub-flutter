import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'native_control.dart';

/// Cuts a page's scrolling content off at the bottom of its bar, but only
/// while native iOS controls are drawn ([NativeControl.readyIn]).
///
/// A native control is a platform view: Flutter's soft top edge cannot fade
/// it and the glass bar cannot cover it, so a switch scrolled under the bar
/// drew over the bar and the status bar. Flutter does apply a clip to a
/// platform view, so under native controls the content stops at the bar
/// instead of fading under it. Every other kit keeps the soft edge.
class NativeCut extends StatelessWidget {
  const NativeCut({super.key, required this.top, required this.child});

  final double top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!NativeControl.readyIn(context)) return child;
    return ClipRect(clipper: _BelowClipper(top), child: child);
  }
}

class _BelowClipper extends CustomClipper<Rect> {
  const _BelowClipper(this.top);

  final double top;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, math.min(top, size.height), size.width, size.height);

  @override
  bool shouldReclip(_BelowClipper old) => old.top != top;
}

