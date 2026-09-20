import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'drop_classifier.dart';
import 'drop_item.dart';

/// One surface that is prepared to receive a drop, as the registry sees it.
///
/// Deliberately a plain object rather than a widget: hit-testing an OS drag
/// cannot go through Flutter's own pointer routing, because there is no
/// pointer. AppKit and the DOM both report a position in window coordinates
/// and nothing else, so the app has to answer "what is under here" itself —
/// which means keeping a list of candidates and their rectangles.
class DropZoneHandle {
  DropZoneHandle({
    required this.key,
    required this.policy,
    required this.priority,
    required this.onEnter,
    required this.onMove,
    required this.onLeave,
    required this.onDrop,
    this.label,
    this.enabled = true,
  });

  /// Anchors the zone in the render tree. Its element is what [rect] measures.
  final GlobalKey key;

  DropPolicy policy;

  /// Higher wins where zones overlap. A chat row (20) sits inside the chat
  /// list; the transcript (0) sits under the composer (10). Ties go to the
  /// smaller rectangle, which is the more specific target by definition.
  final int priority;

  /// What the verdict chip says this zone IS — "Send to Alice", the room's
  /// name. Null for a zone that speaks for the whole window.
  String? label;

  bool enabled;

  /// Set once, by [DropZoneRegistry.unregister], and never cleared.
  ///
  /// `DropController` keeps a reference to whichever handle the pointer is
  /// over, and a widget can leave the tree in the middle of a drag — a route
  /// pop, a chat list rebuilding around a room that just moved, a pane the
  /// shell swapped out. The state's `dispose` takes its notifier with it, so
  /// calling back into the handle after that point is a write to a disposed
  /// `ValueNotifier`, which asserts in debug and is a leak in release.
  ///
  /// The registry is the only thing that knows when a zone has gone, and the
  /// controller is the only thing still holding a reference to it — this flag
  /// is the one bit that connects them.
  bool detached = false;

  final void Function(Offset local) onEnter;
  final void Function(Offset local) onMove;
  final VoidCallback onLeave;

  /// Performs the drop.
  ///
  /// Awaited by the controller — and only by the controller — so the platform
  /// knows when the staged copies behind [DroppedFile.path] can be deleted. A
  /// zone that opens the photo editor therefore holds the bytes for as long as
  /// the editor is up, which is exactly the intent.
  final Future<void> Function(DropBundle bundle) onDrop;

  /// Where this zone is on screen right now, in Flutter's global coordinates,
  /// clipped to the scrollable it lives in.
  ///
  /// The clip is what keeps a chat row that has scrolled up under the search
  /// field from still claiming the pointer: `localToGlobal` reports where a
  /// row WOULD paint, and a `ListView` happily lays out rows past both ends of
  /// its viewport. Without the intersection, hovering the header would light
  /// up whichever row happened to be laid out behind it.
  Rect? get rect {
    final context = key.currentContext;
    if (context == null) return null;
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) return null;
    var bounds = object.localToGlobal(Offset.zero) & object.size;
    final clip = _viewportClipOf(object);
    if (clip != null) {
      bounds = bounds.intersect(clip);
      if (bounds.isEmpty) return null;
    }
    return bounds;
  }

  static Rect? _viewportClipOf(RenderBox box) {
    RenderObject? node = box.parent;
    while (node != null) {
      if (node is RenderAbstractViewport && node is RenderBox) {
        final viewport = node as RenderBox;
        if (!viewport.attached || !viewport.hasSize) return null;
        return viewport.localToGlobal(Offset.zero) & viewport.size;
      }
      node = node.parent;
    }
    return null;
  }
}

/// Every [DropZoneHandle] currently mounted.
///
/// A process-lifetime singleton with no listeners of its own — zones add and
/// remove themselves, and `DropController` asks it a question per mouse move.
/// The list is short by construction (a transcript, a composer, and however
/// many chat rows are on screen, so tens at the very worst), and the question
/// is a rectangle containment test per entry, so this stays a linear scan
/// rather than growing a quadtree nobody would be able to debug.
class DropZoneRegistry {
  DropZoneRegistry._();
  static final DropZoneRegistry instance = DropZoneRegistry._();

  /// Test seam — a fresh registry, so one test's zones cannot leak into the
  /// next one's hit test.
  @visibleForTesting
  DropZoneRegistry.forTest();

  final List<DropZoneHandle> _zones = [];

  @visibleForTesting
  int get length => _zones.length;

  void register(DropZoneHandle handle) {
    if (_zones.contains(handle)) return;
    _zones.add(handle);
  }

  void unregister(DropZoneHandle handle) {
    handle.detached = true;
    handle.enabled = false;
    _zones.remove(handle);
  }

  /// The zone that owns [global], or null for empty space.
  ///
  /// Highest priority first, then the smallest rectangle. The second rule is
  /// what makes nesting work without every caller having to hand-pick a
  /// number: a zone drawn inside another zone at the same priority is, by
  /// virtue of fitting inside it, the more specific answer.
  DropZoneHandle? hitTest(Offset global) {
    DropZoneHandle? best;
    Rect? bestRect;
    for (final zone in _zones) {
      if (!zone.enabled || zone.detached) continue;
      final rect = zone.rect;
      if (rect == null || !rect.contains(global)) continue;
      if (best == null) {
        best = zone;
        bestRect = rect;
        continue;
      }
      if (zone.priority > best.priority) {
        best = zone;
        bestRect = rect;
      } else if (zone.priority == best.priority &&
          _area(rect) < _area(bestRect!)) {
        best = zone;
        bestRect = rect;
      }
    }
    return best;
  }

  static double _area(Rect r) => r.width * r.height;
}
