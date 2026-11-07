import 'package:flutter/widgets.dart';

/// Marks where a page's bar ends, so native iOS controls in the page's
/// scrolling content stop there ([NativeControl] cuts its overlay view at
/// this line).
///
/// Native controls are views above Flutter: the glass bar cannot cover them
/// and the soft top edge cannot fade them, so without this a switch scrolled
/// under the bar would draw over the bar and the status bar. Flutter content
/// itself is never clipped here: it keeps scrolling softly under the bar in
/// every kit.
class NativeCut extends StatefulWidget {
  const NativeCut({super.key, required this.top, required this.child});

  /// The bar's bottom, measured from this widget's top.
  final double top;
  final Widget child;

  /// A function giving the line in global coordinates, or null outside any
  /// [NativeCut]. Measured when called, so it follows the page.
  static double? Function()? lineOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_NativeCutScope>();
    final state = scope?.state;
    if (state == null) return null;
    return state._line;
  }

  @override
  State<NativeCut> createState() => _NativeCutState();
}

class _NativeCutState extends State<NativeCut> {
  double? _line() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    return rect.top + widget.top;
  }

  @override
  Widget build(BuildContext context) =>
      _NativeCutScope(state: this, top: widget.top, child: widget.child);
}

class _NativeCutScope extends InheritedWidget {
  const _NativeCutScope({
    required this.state,
    required this.top,
    required super.child,
  });

  final _NativeCutState state;
  final double top;

  @override
  bool updateShouldNotify(_NativeCutScope old) =>
      old.state != state || old.top != top;
}
