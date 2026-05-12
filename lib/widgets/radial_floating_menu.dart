import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../theme/theme_scope.dart';

/// Gesture-driven radial pie menu for major-section switching.
///
/// Faithful port of v02's `FloatingMenu` (BaseView.swift):
///   - Anchored bottom-leading with 24pt padding.
///   - 3 items fan out in a quadrant from straight-up to roughly-right.
///   - Angles: `-π/2.2 + π/4.5 * i` for i ∈ [0..2]. Distance: 90pt when open.
///   - Gesture is computed from drag TRANSLATION (dx,dy from touch start),
///     not absolute positions. distance > 40 starts highlighting; closest
///     angle wins.
///   - Orb rotates 45° while expanded, plus a light/selection/medium haptic
///     trio (expand / hover-change / commit).
class RadialFloatingMenu extends StatefulWidget {
  const RadialFloatingMenu({
    super.key,
    required this.items,
    required this.active,
    required this.onSelect,
  });

  final List<RadialMenuItem> items;
  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;

  @override
  State<RadialFloatingMenu> createState() => _RadialFloatingMenuState();
}

class RadialMenuItem {
  const RadialMenuItem({required this.section, required this.icon, required this.label});
  final HomeSection section;
  final IconData icon;
  final String label;
}

class _RadialFloatingMenuState extends State<RadialFloatingMenu>
    with SingleTickerProviderStateMixin {
  // Geometry — matches v02 (BaseView.swift)
  static const double _padding = 24;
  static const double _orbSize = 56;
  static const double _itemSize = 44;
  static const double _radius = 90;
  static const double _hoverMinDistance = 40;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  bool _expanded = false;
  int _hoveredIndex = -1;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Angle for slot [i], measured the same way as v02:
  /// `-π/2.2 + (π/4.5) * i`. Positive y is DOWN in screen coords, so these
  /// negative angles point up and to the right.
  double _slotAngle(int i) => -math.pi / 2.2 + (math.pi / 4.5) * i;

  int _indexForDrag(Offset translation) {
    final dist = translation.distance;
    if (dist < _hoverMinDistance) return -1;
    final angle = math.atan2(translation.dy, translation.dx);
    int best = 0;
    double bestDelta = double.infinity;
    for (var i = 0; i < widget.items.length; i++) {
      var d = (angle - _slotAngle(i)).abs();
      // Wrap so we always take the shorter way around the circle.
      if (d > math.pi) d = (2 * math.pi) - d;
      if (d < bestDelta) {
        bestDelta = d;
        best = i;
      }
    }
    // Demand reasonable proximity — outside this, nothing is hovered.
    if (bestDelta > (math.pi / widget.items.length) * 1.15) return -1;
    return best;
  }

  void _onPanStart(DragStartDetails _) {
    setState(() {
      _expanded = true;
      _hoveredIndex = -1;
    });
    _ctrl.forward();
    HapticFeedback.lightImpact();
  }

  Offset _accum = Offset.zero;
  void _onPanDown(DragDownDetails d) {
    _accum = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _accum += d.delta;
    final next = _indexForDrag(_accum);
    if (next != _hoveredIndex) {
      setState(() => _hoveredIndex = next);
      if (next >= 0) HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_hoveredIndex >= 0) {
      widget.onSelect(widget.items[_hoveredIndex].section);
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _expanded = false;
      _hoveredIndex = -1;
    });
    _ctrl.reverse();
  }

  void _onPanCancel() {
    setState(() {
      _expanded = false;
      _hoveredIndex = -1;
    });
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          // The whole gesture surface fits in a square around the orb that is
          // wide enough to host all expanded items. Outside this surface, the
          // app keeps receiving normal taps.
          child: SizedBox(
            width: _orbSize + _radius + _itemSize,
            height: _orbSize + _radius + _itemSize,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = Curves.easeOutBack.transform(_ctrl.value.clamp(0.0, 1.0));
                return Stack(
                  alignment: Alignment.bottomLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // Items
                    for (var i = 0; i < widget.items.length; i++)
                      _buildItem(i, t, theme),
                    // Orb (anchored at the bottom-left of the surface)
                    _OrbGesture(
                      onDown: _onPanDown,
                      onStart: _onPanStart,
                      onUpdate: _onPanUpdate,
                      onEnd: _onPanEnd,
                      onCancel: _onPanCancel,
                      child: _Orb(theme: theme, expanded: _expanded, activeSection: widget.active),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int i, double t, theme) {
    final angle = _slotAngle(i);
    final dx = math.cos(angle) * _radius * t;
    final dy = math.sin(angle) * _radius * t;
    // Anchor each item's center at the orb's center: shift item by half its
    // size to align centers, then offset by (dx, dy).
    return Positioned(
      left: (_orbSize - _itemSize) / 2 + dx,
      // We're in a stack aligned bottom-left, so we use `bottom` and subtract
      // the upward dy (dy is negative for items above the orb).
      bottom: (_orbSize - _itemSize) / 2 - dy,
      child: IgnorePointer(
        ignoring: t < 0.05,
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: _Slice(
            theme: theme,
            item: widget.items[i],
            active: widget.active == widget.items[i].section,
            hovered: _hoveredIndex == i,
          ),
        ),
      ),
    );
  }
}

/// Wraps the orb in a horizontal-or-vertical pan recognizer so we can use
/// pure translation, not absolute positions. The gesture only starts on the
/// orb but tracks the finger anywhere on screen.
class _OrbGesture extends StatelessWidget {
  const _OrbGesture({
    required this.child,
    required this.onDown,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });
  final Widget child;
  final GestureDragDownCallback onDown;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: onDown,
      onPanStart: onStart,
      onPanUpdate: onUpdate,
      onPanEnd: onEnd,
      onPanCancel: onCancel,
      child: child,
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.theme, required this.expanded, required this.activeSection});
  final dynamic theme;
  final bool expanded;
  final HomeSection activeSection;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.125 : 0, // 45°
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: Container(
        width: _RadialFloatingMenuState._orbSize,
        height: _RadialFloatingMenuState._orbSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.accent, theme.accentSoft.withValues(alpha: 0.9)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(Icons.add, color: theme.accentInk, size: 24),
      ),
    );
  }
}

class _Slice extends StatelessWidget {
  const _Slice({required this.theme, required this.item, required this.active, required this.hovered});
  final dynamic theme;
  final RadialMenuItem item;
  final bool active;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final scale = hovered ? 1.30 : (active ? 1.10 : 1.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: _RadialFloatingMenuState._itemSize,
      height: _RadialFloatingMenuState._itemSize,
      transform: Matrix4.identity()..scaleByDouble(scale, scale, scale, 1),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: (hovered || active)
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.accent, theme.accent.withValues(alpha: 0.7)],
              )
            : null,
        color: (hovered || active) ? null : theme.surfaceRaised,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: hovered ? 0.45 : (active ? 0.25 : 0.15)),
            blurRadius: hovered ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        item.icon,
        color: (hovered || active) ? theme.accentInk : theme.inkSoft,
        size: 18,
      ),
    );
  }
}
