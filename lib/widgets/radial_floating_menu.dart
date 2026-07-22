import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';

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
  const RadialMenuItem({
    required this.section,
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });
  final HomeSection section;
  final IconData icon;
  final String label;

  /// Shows a dot on the orb when > 0. A number would collide with the icon
  /// at this size, and the orb only has to say "look here", not how much.
  final int badgeCount;
}

class _RadialFloatingMenuState extends State<RadialFloatingMenu>
    with SingleTickerProviderStateMixin {
  // Geometry — refined from v02 (BaseView.swift) for a lighter resting state.
  static const double _padding = 24;
  static const double _orbSize = 52;
  static const double _itemSize = 44;
  static const double _radius = 96;
  static const double _hoverMinDistance = 36;
  static const Duration _expandDuration = Duration(milliseconds: 260);
  static const Duration _collapseDuration = Duration(milliseconds: 200);
  // Per-item stagger when fanning out. Item i starts at t = _stagger * i of
  // the master controller and runs through its own easeOutCubic to t = 1.0.
  static const double _stagger = 0.18;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _expandDuration,
    reverseDuration: _collapseDuration,
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

  /// Cupertino glyph used by the orb when the user is on a given section.
  /// Matches the icons passed in via `RadialMenuItem` so the orb visually
  /// echoes the active item.
  IconData _iconForSection(HomeSection s) {
    switch (s) {
      case HomeSection.chat:
        return CupertinoIcons.bubble_left;
      case HomeSection.feed:
        return CupertinoIcons.sparkles;
      case HomeSection.settings:
        return CupertinoIcons.gear;
    }
  }

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
                return Stack(
                  alignment: Alignment.bottomLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // Items
                    for (var i = 0; i < widget.items.length; i++)
                      _buildItem(i, theme),
                    // Orb (anchored at the bottom-left of the surface)
                    _OrbGesture(
                      onDown: _onPanDown,
                      onStart: _onPanStart,
                      onUpdate: _onPanUpdate,
                      onEnd: _onPanEnd,
                      onCancel: _onPanCancel,
                      child: _Orb(
                        theme: theme,
                        expanded: _expanded,
                        icon: _iconForSection(widget.active),
                      ),
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

  Widget _buildItem(int i, AppTheme theme) {
    // Per-item progress: item i starts at t = _stagger * i and runs its own
    // easeOutCubic to t = 1.0. This makes items fan out sequentially rather
    // than all at once.
    final tItem = Interval(_stagger * i, 1.0, curve: Curves.easeOutCubic)
        .transform(_ctrl.value.clamp(0.0, 1.0));
    final angle = _slotAngle(i);
    final dx = math.cos(angle) * _radius * tItem;
    final dy = math.sin(angle) * _radius * tItem;
    return Positioned(
      left: (_orbSize - _itemSize) / 2 + dx,
      bottom: (_orbSize - _itemSize) / 2 - dy,
      child: IgnorePointer(
        ignoring: tItem < 0.05,
        child: Opacity(
          opacity: tItem.clamp(0.0, 1.0),
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
  const _Orb({required this.theme, required this.expanded, required this.icon});
  final AppTheme theme;
  final bool expanded;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: expanded ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: _RadialFloatingMenuState._orbSize,
        height: _RadialFloatingMenuState._orbSize,
        decoration: BoxDecoration(
          color: theme.accent,
          shape: BoxShape.circle,
          border: Border.all(color: theme.ink.withValues(alpha: 0.18), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: theme.accent.withValues(alpha: expanded ? 0.30 : 0.22),
              blurRadius: expanded ? 16 : 12,
              offset: Offset(0, expanded ? 6 : 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: theme.accentInk, size: 22),
      ),
    );
  }
}

class _Slice extends StatelessWidget {
  const _Slice({required this.theme, required this.item, required this.active, required this.hovered});
  final AppTheme theme;
  final RadialMenuItem item;
  final bool active;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    // State precedence: hovered > active > idle.
    final Color fill;
    final Color? borderColor;
    final double borderWidth;
    final Color iconColor;
    final List<BoxShadow> shadow;
    final double scale;
    if (hovered) {
      fill = theme.accent;
      borderColor = null;
      borderWidth = 0;
      iconColor = theme.accentInk;
      shadow = [
        BoxShadow(
          color: theme.accent.withValues(alpha: 0.32),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
      scale = 1.10;
    } else if (active) {
      fill = theme.accentSoft;
      borderColor = theme.accent;
      borderWidth = 1;
      iconColor = theme.accent;
      shadow = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];
      scale = 1.0;
    } else {
      fill = theme.surface.withValues(alpha: 0.85);
      borderColor = theme.divider;
      borderWidth = 0.5;
      iconColor = theme.inkSoft;
      shadow = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];
      scale = 1.0;
    }
    final orb = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: _RadialFloatingMenuState._itemSize,
          height: _RadialFloatingMenuState._itemSize,
          transform: Matrix4.identity()..scaleByDouble(scale, scale, scale, 1),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: borderColor == null ? null : Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadow,
          ),
          alignment: Alignment.center,
          child: Icon(item.icon, color: iconColor, size: 20),
        ),
      ),
    );
    if (item.badgeCount <= 0) return orb;
    // Outside the ClipOval — inside it the dot would be clipped away by the
    // orb's own circular mask.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        orb,
        Positioned(
          top: 2,
          right: 2,
          child: DotBadge(show: true),
        ),
      ],
    );
  }
}
