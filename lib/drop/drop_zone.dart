import 'package:flutter/widgets.dart';

import '../widgets/drop/drop_glow.dart';
import 'drop_classifier.dart';
import 'drop_controller.dart';
import 'drop_item.dart';
import 'drop_zone_registry.dart';

/// Where the pointer is inside a zone, and what it is carrying.
@immutable
class DropZoneHover {
  const DropZoneHover({required this.local, required this.plan});

  /// Pointer position in the zone's own coordinates, which is what the
  /// spotlight is centred on.
  final Offset local;

  final DropPlan plan;

  DropTone get tone => plan.tone;

  @override
  bool operator ==(Object other) =>
      other is DropZoneHover && other.local == local && other.plan == plan;

  @override
  int get hashCode => Object.hash(local, plan);
}

/// Makes its subtree a target for files dragged in from the OS.
///
/// Inert on every platform without a desktop drag: [DropController.isSupported]
/// is false on iOS and Android, so nothing registers, nothing paints and the
/// widget costs one `if` per build. That is the whole reason this is a widget
/// wrapped around things rather than a property threaded through them — a
/// surface can simply declare itself droppable and stop thinking about it.
///
/// ### What it does NOT do
///
/// It does not hit-test through Flutter. An OS drag produces no pointer
/// events, so there is nothing for `Listener` or `MouseRegion` to see — see
/// [DropZoneRegistry] for the rectangle bookkeeping that replaces them. The
/// practical consequence is that a zone must be *painted* to be hit: a route
/// pushed over this one leaves its zones registered and still measurable, so
/// anything that can be covered should either be disabled while covered or
/// outranked by a zone on top of it.
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.child,
    required this.onDrop,
    this.policy = DropPolicy.permissive,
    this.priority = 0,
    this.label,
    this.enabled = true,
    this.borderRadius,
    this.showGlow = true,
    this.glowInset = EdgeInsets.zero,
    this.lift = 0,
    this.respectRouteCoverage = true,
  });

  final Widget child;

  /// Handles a completed drop. Awaited — the bytes behind the bundle live for
  /// exactly as long as this future does.
  final Future<void> Function(DropBundle bundle) onDrop;

  /// What this surface accepts. Rebuilt on every `build` by callers that read
  /// a live permission, so a supervised account losing media mid-drag is
  /// refused before it lands.
  final DropPolicy policy;

  /// Higher wins where zones overlap; ties go to the smaller rectangle.
  final int priority;

  /// The name the verdict chip uses — "Send to Alice". Null lets the chip
  /// speak generically.
  final String? label;

  final bool enabled;

  /// Shape of the glow. Defaults to a 20pt rounded rectangle, which is this
  /// app's `radiusLg`-ish default for a full surface.
  final BorderRadius? borderRadius;

  /// False leaves the zone live but silent, for a surface that draws its own
  /// hover treatment.
  final bool showGlow;

  /// Pulls the glow in from the zone's edges. A full-screen transcript wants a
  /// margin so the ring reads as a frame rather than as a window border.
  final EdgeInsets glowInset;

  /// How far the subtree rises under a hover, in logical pixels. Zero for
  /// anything big (a transcript that scales is a transcript that reflows);
  /// a point or two for a row, where it is the difference between a highlight
  /// and something that feels picked up.
  final double lift;

  /// Whether a route pushed on top of this one switches the zone off.
  ///
  /// It has to, and nothing else can do it. A zone is hit-tested by its
  /// RECTANGLE, and a rectangle does not stop existing because a photo editor
  /// was pushed over it — so without this, dropping a file onto an open editor
  /// would quietly send it to the transcript behind. `secondaryAnimation` is
  /// the signal: Flutter drives it from 0 to 1 on exactly the route that is
  /// being covered, which makes "am I underneath something" a listenable
  /// rather than something to poll.
  ///
  /// False for a zone with no route of its own to speak for it.
  final bool respectRouteCoverage;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  final GlobalKey _anchor = GlobalKey();
  final ValueNotifier<DropZoneHover?> _hover = ValueNotifier(null);
  DropZoneHandle? _handle;

  Animation<double>? _coverage;
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    if (!DropController.isSupported) return;
    final handle = DropZoneHandle(
      key: _anchor,
      policy: widget.policy,
      priority: widget.priority,
      label: widget.label,
      enabled: widget.enabled,
      onEnter: _onEnter,
      onMove: _onMove,
      onLeave: _onLeave,
      onDrop: widget.onDrop,
    );
    _handle = handle;
    DropZoneRegistry.instance.register(handle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handle == null || !widget.respectRouteCoverage) return;
    final next = ModalRoute.of(context)?.secondaryAnimation;
    if (identical(next, _coverage)) return;
    _coverage?.removeListener(_onCoverageChanged);
    _coverage = next;
    _coverage?.addListener(_onCoverageChanged);
    _onCoverageChanged();
  }

  /// Halfway, not "anything above zero": the animation is also what runs while
  /// the covering route is being POPPED, and a zone that stays dead until the
  /// last frame of a dismissal is a zone that refuses a drop onto a screen the
  /// user is already looking at.
  void _onCoverageChanged() {
    final covered = (_coverage?.value ?? 0) > 0.5;
    if (covered == _covered) return;
    _covered = covered;
    _handle?.enabled = widget.enabled && !covered;
    if (covered) _hover.value = null;
  }

  @override
  void didUpdateWidget(DropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mutated in place rather than re-registered. The handle's identity is
    // what `DropController` compares against to decide whether the pointer has
    // crossed a boundary; swapping it on a policy change would read as a
    // crossing and restart the hover animation mid-drag.
    final handle = _handle;
    if (handle == null) return;
    handle.policy = widget.policy;
    handle.label = widget.label;
    handle.enabled = widget.enabled && !_covered;
    if (!handle.enabled && _hover.value != null) _hover.value = null;
  }

  @override
  void dispose() {
    _coverage?.removeListener(_onCoverageChanged);
    final handle = _handle;
    if (handle != null) DropZoneRegistry.instance.unregister(handle);
    _hover.dispose();
    super.dispose();
  }

  void _onEnter(Offset local) => _hover.value = DropZoneHover(
        local: local,
        plan: DropController.instance.plan,
      );

  void _onMove(Offset local) {
    final current = _hover.value;
    if (current == null) {
      _onEnter(local);
      return;
    }
    _hover.value = DropZoneHover(local: local, plan: DropController.instance.plan);
  }

  void _onLeave() => _hover.value = null;

  @override
  Widget build(BuildContext context) {
    if (!DropController.isSupported) return widget.child;
    return KeyedSubtree(
      key: _anchor,
      child: widget.showGlow
          ? DropGlow(
              hover: _hover,
              borderRadius: widget.borderRadius,
              inset: widget.glowInset,
              lift: widget.lift,
              child: widget.child,
            )
          : widget.child,
    );
  }
}
