import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

/// A lazy transcript whose rows keep their render objects when pagination,
/// typing indicators or send acknowledgements move them to another index.
/// Keys alone are insufficient for a builder delegate: it also needs the
/// mapping back to each row's new index, or loaded media can mount again at
/// its placeholder height and pull the viewport under a drag or fling.
class TimelineListView extends StatelessWidget {
  const TimelineListView({
    super.key,
    required this.controller,
    required this.rowKeys,
    required this.itemBuilder,
    this.padding,
    this.preserveAtStart = false,
  });

  final ScrollController controller;
  final List<Key> rowKeys;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final bool preserveAtStart;

  @override
  Widget build(BuildContext context) {
    final indices = {for (var i = 0; i < rowKeys.length; i++) rowKeys[i]: i};
    assert(
      indices.length == rowKeys.length,
      'Transcript row keys must be unique',
    );
    return CustomScrollView(
      controller: controller,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: padding ?? EdgeInsets.zero,
          sliver: _AnchoredSliverList(
            rowKeys: rowKeys,
            preserveAtStart: preserveAtStart,
            delegate: SliverChildBuilderDelegate(
              (context, index) => KeyedSubtree(
                key: rowKeys[index],
                child: itemBuilder(context, index),
              ),
              childCount: rowKeys.length,
              findChildIndexCallback: (key) => indices[key],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnchoredSliverList extends SliverList {
  const _AnchoredSliverList({
    required super.delegate,
    required this.rowKeys,
    required this.preserveAtStart,
  });
  final List<Key> rowKeys;
  final bool preserveAtStart;

  @override
  RenderSliverList createRenderObject(BuildContext context) =>
      _AnchoredRenderList(
        childManager: context as SliverMultiBoxAdaptorElement,
        rowKeys: rowKeys,
        preserveAtStart: preserveAtStart,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _AnchoredRenderList renderObject,
  ) {
    renderObject.preserveAtStart = preserveAtStart;
    renderObject.rowKeys = rowKeys;
  }
}

class _AnchoredRenderList extends RenderSliverList {
  _AnchoredRenderList({
    required super.childManager,
    required List<Key> rowKeys,
    required this.preserveAtStart,
  }) : _rowKeys = rowKeys;
  List<Key> _rowKeys;
  bool preserveAtStart;
  ({Key key, double offset})? _anchor;

  final _retained = <RenderBox, bool>{};

  set rowKeys(List<Key> value) {
    if (listEquals(_rowKeys, value)) return;
    // This runs before the delegate reorders its children. Remember a visible
    // row's content offset, then compare it with its new offset after layout.
    // At the live tail, keep following the newest message instead.
    _anchor ??= _captureAnchor();
    // Retain the existing cache through the correction so loaded media is
    // not discarded by the temporary, uncorrected viewport.
    if (_anchor != null) {
      for (var child = firstChild; child != null; child = childAfter(child)) {
        final data = child.parentData! as SliverMultiBoxAdaptorParentData;
        _retained.putIfAbsent(child, () => data.keepAlive);
        data.keepAlive = true;
      }
    }
    _rowKeys = value;
    markNeedsLayout();
  }

  ({Key key, double offset})? _captureAnchor() {
    if (geometry != null && (constraints.scrollOffset > 0 || preserveAtStart)) {
      for (var child = firstChild; child != null; child = childAfter(child)) {
        final data = child.parentData! as SliverMultiBoxAdaptorParentData;
        final offset = data.layoutOffset;
        final index = data.index;
        if (offset != null &&
            index != null &&
            index < _rowKeys.length &&
            offset + paintExtentOf(child) > constraints.scrollOffset &&
            offset <
                constraints.scrollOffset + constraints.remainingPaintExtent) {
          return (key: _rowKeys[index], offset: offset);
        }
      }
    }
    return null;
  }

  @override
  void performLayout() {
    // A decode or link preview can resize existing rows without changing any
    // keys. Anchor those layouts too, using their offsets from the last frame.
    final anchor = _anchor ?? _captureAnchor();
    for (final child in _retained.keys) {
      final data = child.parentData;
      if (data is SliverMultiBoxAdaptorParentData) data.keepAlive = true;
    }
    super.performLayout();
    if (geometry!.scrollOffsetCorrection != null) {
      _anchor = anchor;
      return;
    }
    if (anchor == null) return;
    final index = _rowKeys.indexOf(anchor.key);
    // Measure through the anchor when an inserted page moved it beyond the
    // initial layout range. This happens once per page, not on scroll frames;
    // the next layout discards those temporary offscreen children normally.
    if (index >= 0) {
      while (lastChild != null && indexOf(lastChild!) < index) {
        final previous = lastChild!;
        final offset = childScrollOffset(previous);
        if (offset == null) break;
        previous.layout(constraints.asBoxConstraints(), parentUsesSize: true);
        final next = insertAndLayoutChild(
          constraints.asBoxConstraints(),
          after: previous,
          parentUsesSize: true,
        );
        if (next == null) break;
        (next.parentData! as SliverMultiBoxAdaptorParentData).layoutOffset =
            offset + paintExtentOf(previous);
      }
    }
    _anchor = null;
    for (final entry in _retained.entries) {
      final data = entry.key.parentData;
      if (data is SliverMultiBoxAdaptorParentData) data.keepAlive = entry.value;
    }
    _retained.clear();
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final data = child.parentData! as SliverMultiBoxAdaptorParentData;
      if (data.index != index || data.layoutOffset == null) continue;
      final delta = data.layoutOffset! - anchor.offset;
      // The viewport applies this during layout, preserving the current drag
      // or ballistic activity. A post-frame jumpTo would cancel either one.
      if (delta.abs() > 0.01) {
        geometry = SliverGeometry(scrollOffsetCorrection: delta);
      }
      return;
    }
  }
}
