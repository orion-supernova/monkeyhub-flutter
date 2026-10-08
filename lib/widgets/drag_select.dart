import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// THE multi-select gesture for a grid of media, the way Photos does it.
///
/// One rule set for every media grid in the app (the room's shared media,
/// Storage Usage, a storage category, a chat's storage page), so a thumb
/// learns it once:
///
///  * a tap opens the item (the tile's own `onTap`; this region adds nothing);
///  * a long press starts selecting, with the pressed item picked;
///  * keeping the finger down and dragging selects every item between where
///    it started and where it is, in grid order, and dragging back unpicks
///    what it passes back over. Started on an item already picked, the same
///    drag unpicks instead;
///  * once selecting, a sideways swipe across the grid does the same without
///    the long press, while an up or down drag still scrolls;
///  * near the top or bottom edge during a drag, the grid scrolls by itself.
///
/// Items are found by position: wrap each tile in a [DragSelectTile] with its
/// id. [ids] is every id in grid order, built or not, so a range can run
/// through rows that are off screen. The region never holds the selection;
/// it hands the whole new set to [onChanged] and draws from [selected].
class DragSelectRegion extends StatefulWidget {
  const DragSelectRegion({
    super.key,
    required this.ids,
    required this.selected,
    required this.selecting,
    required this.onChanged,
    required this.child,
    this.scroll,
  });

  final List<String> ids;
  final Set<String> selected;

  /// Whether selection mode is on, which turns a sideways swipe into a
  /// selecting drag.
  final bool selecting;

  /// The new selection. Called with selection mode implied on.
  final ValueChanged<Set<String>> onChanged;

  /// The grid's scroller, for scrolling by itself near an edge.
  final ScrollController? scroll;
  final Widget child;

  @override
  State<DragSelectRegion> createState() => _DragSelectRegionState();
}

class _DragSelectRegionState extends State<DragSelectRegion> {
  final Map<String, BuildContext> _tiles = {};

  /// The drag in progress: where it started, the selection it started from,
  /// and whether it picks or unpicks.
  int? _anchor;
  Set<String> _base = const {};
  bool _picking = true;
  int? _last;
  Offset? _pointer;
  Timer? _autoScroll;

  void _register(String id, BuildContext context) => _tiles[id] = context;
  void _unregister(String id, BuildContext context) {
    if (identical(_tiles[id], context)) _tiles.remove(id);
  }

  /// The id of the tile under [global], among those currently built.
  String? _hit(Offset global) {
    for (final e in _tiles.entries) {
      final box = e.value.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final local = box.globalToLocal(global);
      if ((Offset.zero & box.size).contains(local)) return e.key;
    }
    return null;
  }

  bool _start(Offset global, {required bool fromLongPress}) {
    final id = _hit(global);
    if (id == null) return false;
    final index = widget.ids.indexOf(id);
    if (index < 0) return false;
    _anchor = index;
    _last = null;
    _pointer = global;
    _base = {...widget.selected};
    _picking = !_base.contains(id);
    if (fromLongPress) HapticFeedback.selectionClick();
    _extend(index);
    return true;
  }

  void _move(Offset global) {
    _pointer = global;
    if (_anchor == null) return;
    final id = _hit(global);
    if (id != null) {
      final index = widget.ids.indexOf(id);
      if (index >= 0) _extend(index);
    }
    _syncAutoScroll(global);
  }

  void _extend(int index) {
    final anchor = _anchor;
    if (anchor == null || index == _last) return;
    _last = index;
    final range = widget.ids.sublist(
      math.min(anchor, index),
      math.max(anchor, index) + 1,
    );
    final next = {..._base};
    if (_picking) {
      next.addAll(range);
    } else {
      next.removeAll(range);
    }
    // A tick per item crossed, the way Photos answers a finger.
    if (next.length != widget.selected.length) HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  void _end() {
    _anchor = null;
    _pointer = null;
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  /// Scrolls while the finger rests near the region's top or bottom edge,
  /// faster the closer it gets, and keeps extending the range under it.
  void _syncAutoScroll(Offset global) {
    final scroll = widget.scroll;
    final box = context.findRenderObject();
    if (scroll == null || !scroll.hasClients || box is! RenderBox) return;
    final local = box.globalToLocal(global);
    const edge = 72.0;
    double speed = 0;
    if (local.dy < edge) speed = -(edge - local.dy) / edge;
    if (local.dy > box.size.height - edge) {
      speed = (local.dy - (box.size.height - edge)) / edge;
    }
    if (speed == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final p = _pointer;
      if (!scroll.hasClients || p == null) return;
      final b = context.findRenderObject();
      if (b is! RenderBox) return;
      final y = b.globalToLocal(p).dy;
      final s = y < edge
          ? -(edge - y) / edge
          : y > b.size.height - edge
              ? (y - (b.size.height - edge)) / edge
              : 0.0;
      if (s == 0) return;
      final pos = scroll.position;
      final to = (pos.pixels + s.clamp(-1.0, 1.0) * 18)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (to == pos.pixels) return;
      scroll.jumpTo(to);
      // New tiles slid under a still finger.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final again = _pointer;
        if (again != null) _move(again);
      });
    });
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(debugOwner: this),
        (r) => r
          ..onLongPressStart =
              ((d) => _start(d.globalPosition, fromLongPress: true))
          ..onLongPressMoveUpdate = ((d) => _move(d.globalPosition))
          ..onLongPressEnd = ((_) => _end())
          ..onLongPressCancel = _end,
      ),
      // Only while selecting: a sideways swipe picks. Up and down still
      // belong to the scroll view, which wins any vertical drag.
      if (widget.selecting)
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(debugOwner: this),
          (r) => r
            ..onStart =
                ((d) => _start(d.globalPosition, fromLongPress: false))
            ..onUpdate = ((d) => _move(d.globalPosition))
            ..onEnd = ((_) => _end())
            ..onCancel = _end,
        ),
    };
    return _DragSelectScope(
      state: this,
      child: RawGestureDetector(
        gestures: gestures,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}

class _DragSelectScope extends InheritedWidget {
  const _DragSelectScope({required this.state, required super.child});
  final _DragSelectRegionState state;

  @override
  bool updateShouldNotify(_DragSelectScope old) => false;
}

/// Marks one tile of a [DragSelectRegion] by its [id], so a drag can find it
/// under the finger.
class DragSelectTile extends StatefulWidget {
  const DragSelectTile({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  State<DragSelectTile> createState() => _DragSelectTileState();
}

class _DragSelectTileState extends State<DragSelectTile> {
  _DragSelectRegionState? _region;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final region = context
        .getInheritedWidgetOfExactType<_DragSelectScope>()
        ?.state;
    if (region != _region) {
      _region?._unregister(widget.id, context);
      _region = region;
    }
    _region?._register(widget.id, context);
  }

  @override
  void didUpdateWidget(DragSelectTile old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _region?._unregister(old.id, context);
      _region?._register(widget.id, context);
    }
  }

  @override
  void dispose() {
    _region?._unregister(widget.id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
