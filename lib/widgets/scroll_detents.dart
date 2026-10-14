import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A light tick each time one of [items] crosses the middle of the scroll
/// below, the way a picker wheel clicks past its rows: under the finger and
/// while a flick coasts on, never for a scroll the app made on its own (a
/// tab brought into view, a jump on open).
///
/// [items] are keys on the children to count; the nearest to the viewport's
/// middle is the one "under" it, and a change of that is a tick.
class ScrollDetents extends StatefulWidget {
  const ScrollDetents({super.key, required this.items, required this.child});

  final List<GlobalKey> items;
  final Widget child;

  @override
  State<ScrollDetents> createState() => _ScrollDetentsState();
}

class _ScrollDetentsState extends State<ScrollDetents> {
  /// A finger started this scroll; stays true through its coast.
  bool _user = false;
  int? _under;

  int? _nearest(ScrollMetrics m, BuildContext viewport) {
    final box = viewport.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final horizontal = m.axis == Axis.horizontal;
    final mid = box.localToGlobal(box.size.center(Offset.zero));
    int? best;
    var bestGap = double.infinity;
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i].currentContext?.findRenderObject();
      if (item is! RenderBox || !item.attached || !item.hasSize) continue;
      final c = item.localToGlobal(item.size.center(Offset.zero));
      final gap = horizontal ? (c.dx - mid.dx).abs() : (c.dy - mid.dy).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    return best;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final viewport = n.context;
    if (viewport == null) return false;
    if (n is ScrollStartNotification) {
      if (n.dragDetails != null) {
        _user = true;
        _under = _nearest(n.metrics, viewport);
      }
    } else if (n is ScrollUpdateNotification) {
      if (!_user) return false;
      final now = _nearest(n.metrics, viewport);
      if (now != null && now != _under) {
        _under = now;
        HapticFeedback.selectionClick();
      }
    } else if (n is ScrollEndNotification) {
      _user = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}
