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
/// Ported from v02's `FloatingMenu` (BaseView.swift), with the geometry made
/// count-derived:
///   - Anchored bottom-leading with 24pt padding.
///   - Items fan out across a fixed 80° quadrant, from straight-up to
///     roughly-right, spaced evenly however many there are.
///   - Gesture is computed from drag TRANSLATION (dx,dy from touch start),
///     not absolute positions. distance > [_hoverMinDistance] starts
///     highlighting; closest angle wins.
///   - Orb rotates 45° while expanded, plus a light/selection/medium haptic
///     trio (expand / hover-change / commit).
///
/// The angles used to be the literal `-π/2.2 + π/4.5 * i`, i.e. a 40° step with
/// three items assumed. A fourth item put slot 3 at +38.2° — below the
/// horizontal — which placed it 55pt *below* the gesture surface, under the
/// home indicator, and `Clip.none` rendered it there rather than clipping it.
/// Deriving the step from the item count keeps the fan inside the quadrant at
/// any count.
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

/// The radial fan's geometry, as pure functions of the item count.
///
/// Separated from the widget so it can be verified directly. The values used to
/// be private constants with the count folded in — `-π/2.2 + π/4.5 * i` assumed
/// exactly three items, and a fourth silently landed below the horizontal, 55pt
/// beneath the gesture surface and under the home indicator, where `Clip.none`
/// rendered it rather than clipping it. Nothing in the widget tree could have
/// caught that; a test over these functions can.
class RadialGeometry {
  const RadialGeometry._();

  /// First slot's angle — straight up, less a little. Screen coords put
  /// positive y DOWN, so negative angles point up.
  static const double spanStart = -math.pi / 2.2; // ≈ -81.8°

  /// Total sweep from first slot to last. 80°, preserved from the original
  /// three-item fan so the menu still occupies the same quadrant.
  static const double spanSweep = math.pi / 2.25; // 80°

  static const double orbSize = 52;
  static const double itemSize = 44;

  /// Raised from 96 when the fan went to four. At a 26.7° step, neighbouring
  /// slot centres sit `2·r·sin(13.3°)` apart: 44.3pt at r=96, which against a
  /// 44pt [itemSize] left a 0.3pt gap — orbs visually touching. r=112 puts
  /// centres 51.7pt apart, a 7.7pt gap.
  static const double radius = 112;

  /// How far past either end of the fan a drag may stray and still commit.
  /// A gesture up-and-left plainly means "the top item" even though it points
  /// outside the fan; one pointing straight down means nothing.
  static const double endOvershoot = math.pi / 3; // 60°

  /// Even spacing of [n] slots across [spanSweep]. A lone item sits in the
  /// middle of the quadrant rather than at its edge.
  static double slotAngle(int i, int n) {
    if (n <= 1) return spanStart + spanSweep / 2;
    return spanStart + (spanSweep / (n - 1)) * i;
  }

  /// Per-item fan-out stagger: item i starts at t = `stagger * i` of the master
  /// controller and runs its own curve to 1.0.
  ///
  /// Derived from the count so the last item always begins halfway through the
  /// expand. A fixed 0.18 gave a fourth item `Interval(0.54, 1.0)` — 46% of the
  /// 260ms to travel the same distance as the first, which read as rushed.
  static double stagger(int n) => n <= 1 ? 0 : 0.5 / (n - 1);

  /// Left offset of slot [i] within the gesture square, at fan progress [t].
  static double left(int i, int n, double t) =>
      (orbSize - itemSize) / 2 + math.cos(slotAngle(i, n)) * radius * t;

  /// Bottom offset of slot [i]. Negative means the item is rendered *below* the
  /// gesture surface — the exact failure a fourth item used to produce.
  static double bottom(int i, int n, double t) =>
      (orbSize - itemSize) / 2 - math.sin(slotAngle(i, n)) * radius * t;

  /// Which slot a drag at [angle] radians selects, or -1 for none.
  ///
  /// Between slots the nearest always wins — a pie menu shouldn't have dead
  /// zones between its wedges. Only an end slot can be "missed", and only by a
  /// gesture straying outside the whole fan by more than [endOvershoot].
  ///
  /// The old rule was `bestDelta > (pi / n) * 1.15`, a tolerance that shrank as
  /// items were added: three to four narrowed it 69° → 51.75°, so a drag
  /// up-and-left that used to select the first item would suddenly select
  /// nothing. A fixed overshoot keeps the feel constant at any count.
  static int indexForAngle(double angle, int n) {
    if (n <= 0) return -1;
    var best = 0;
    var bestDelta = double.infinity;
    for (var i = 0; i < n; i++) {
      var d = (angle - slotAngle(i, n)).abs();
      // Wrap so we always take the shorter way around the circle.
      if (d > math.pi) d = (2 * math.pi) - d;
      if (d < bestDelta) {
        bestDelta = d;
        best = i;
      }
    }
    if ((best == 0 || best == n - 1) && bestDelta > endOvershoot) return -1;
    return best;
  }
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
  static const double _orbSize = RadialGeometry.orbSize;
  static const double _itemSize = RadialGeometry.itemSize;
  static const double _radius = RadialGeometry.radius;
  static const double _hoverMinDistance = 36;
  static const Duration _expandDuration = Duration(milliseconds: 260);
  static const Duration _collapseDuration = Duration(milliseconds: 200);

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

  int get _n => widget.items.length;
  double get _stagger => RadialGeometry.stagger(_n);

  /// Glyph the resting orb wears, echoing whichever item is active.
  ///
  /// Resolved from the items themselves rather than a parallel switch. It used
  /// to be its own `HomeSection -> IconData` map, which meant the orb's glyph
  /// and the fan item for the same section were two independent claims about
  /// one thing — exactly what `navDestinations` was made the single source of
  /// truth to prevent.
  IconData _iconForSection(HomeSection s) {
    for (final item in widget.items) {
      if (item.section == s) return item.icon;
    }
    return CupertinoIcons.bubble_left;
  }

  int _indexForDrag(Offset translation) {
    if (translation.distance < _hoverMinDistance) return -1;
    return RadialGeometry.indexForAngle(
      math.atan2(translation.dy, translation.dx),
      _n,
    );
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
    final tItem = Interval(
      _stagger * i,
      1.0,
      curve: Curves.easeOutCubic,
    ).transform(_ctrl.value.clamp(0.0, 1.0));
    return Positioned(
      left: RadialGeometry.left(i, _n, tItem),
      bottom: RadialGeometry.bottom(i, _n, tItem),
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
          border: Border.all(
            color: theme.ink.withValues(alpha: 0.18),
            width: 0.5,
          ),
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
  const _Slice({
    required this.theme,
    required this.item,
    required this.active,
    required this.hovered,
  });
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
            border: borderColor == null
                ? null
                : Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadow,
          ),
          alignment: Alignment.center,
          child: Icon(item.icon, color: iconColor, size: 20),
        ),
      ),
    );
    // The fan is icon-only by design, so [RadialMenuItem.label] is what names
    // each orb to a screen reader. Without this the labels were dead strings
    // and the menu was four unnamed circles to VoiceOver.
    Widget named(Widget child) => Semantics(
      label: item.badgeCount > 0
          ? '${item.label}, ${item.badgeCount} waiting'
          : item.label,
      button: true,
      selected: active,
      child: ExcludeSemantics(child: child),
    );

    if (item.badgeCount <= 0) return named(orb);
    // Outside the ClipOval — inside it the dot would be clipped away by the
    // orb's own circular mask.
    return named(
      Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          orb,
          Positioned(top: 2, right: 2, child: DotBadge(show: true)),
        ],
      ),
    );
  }
}
