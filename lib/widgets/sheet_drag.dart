import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;

import '../theme/motion.dart';

// Pull-down-to-dismiss from a sheet's SCROLLING body — the iOS behaviour the
// user missed on the point composer: a body scrolled to its top pulls the
// whole sheet down with the finger, and letting go far enough (or fast
// enough) closes it.
//
// `BottomSheet` only drags from regions that do not claim the vertical drag
// themselves — the handle and the bar. A scroll view claims it, so on a sheet
// whose body scrolls, the body could only ever scroll. The fix lives in the
// body's scroll PHYSICS rather than in overscroll notifications: physics see
// every pixel of the drag before the position does, so they can hand the
// part past the top to the sheet, and take it back when the finger turns
// round, without the content and the sheet ever fighting for the same
// pixels.
//
// The host hands those physics to EVERY vertical scroll view under it,
// through the [ScrollConfiguration], so a sheet's list pulls it closed
// without opting in. A scroll view's own physics (a `ClampingScrollPhysics`,
// an `AlwaysScrollableScrollPhysics`) wraps them as its parent, and the
// pull still sees every pixel: neither of those overrides the user offset.
// `BouncingScrollPhysics` does, and never asks its parent, so a sheet's
// scroller must not name it.

/// The host of a sheet's motion: owns the spring that presents it, follows
/// the finger 1:1 while it is dragged, and decides on release whether to close
/// it (with the fling's own velocity) or spring it home.
/// `showAdaptiveSheet` wraps every compact sheet in one; nothing else should.
///
/// ONE physics for every way of pulling: a drag on the grabber, the bar or any
/// still part of the panel (a [GestureDetector] here — a scroll view deeper in
/// the tree wins the arena over it) and the pull a scrolled-to-top body hands
/// over through [SheetPullPhysics] both move the same value. Pulled UP past
/// rest, the sheet rubber-bands at x0.25. Released past 40% of its height or
/// faster than 700 px/s, it springs off the screen carrying the finger's
/// speed; otherwise it springs back, carrying that speed too.
///
/// [animateIn] makes the host present its child from below the screen with a
/// spring on first build, and exit with one whenever the route starts to pop
/// (by any path: the barrier, a button, Android back). [offscreenExtra] is how
/// far past its own height the sheet must travel to be out of sight (the gap
/// the floating sheet leaves under itself).
///
/// [enabled] false (a sheet presented with `enableDrag: false` or
/// `isDismissible: false`) makes the body an ordinary scroll view. A sheet
/// under a `PopScope(canPop: false)` ignores the pull too. Calm motion
/// presents and exits instantly; dragging still follows the finger.
class SheetDragHost extends StatefulWidget {
  const SheetDragHost({
    super.key,
    required this.child,
    this.enabled = true,
    this.animateIn = false,
    this.offscreenExtra = 0,
  });

  final Widget child;
  final bool enabled;
  final bool animateIn;
  final double offscreenExtra;

  /// How far the nearest host has pulled its sheet down, in logical pixels —
  /// for tests and for a body that wants to react to the pull. Null outside
  /// a compact sheet (the desktop popover has no host).
  static ValueListenable<double>? offsetOf(BuildContext context) =>
      _SheetDragScope.maybeOf(context)?.offset;

  @override
  State<SheetDragHost> createState() => _SheetDragHostState();
}

/// Past this share of the sheet's height, a release closes it.
const double _kDismissFraction = 0.4;

/// A downward release faster than this (logical px/s) closes it whatever the
/// distance — the flick.
const double _kDismissVelocity = 700;

/// Pulled above its resting place, the sheet follows the finger at this share.
const double _kRubberBand = 0.25;

/// iOS `.smooth`: k300 c30, response 0.363 / damping ratio 0.866.
const SpringDescription _kPresentSpring =
    SpringDescription(mass: 1, stiffness: 300, damping: 30);

/// Critically damped and quick: an exit must not wobble.
const SpringDescription _kExitSpring =
    SpringDescription(mass: 1, stiffness: 600, damping: 48.99);

class _SheetDragHostState extends State<SheetDragHost>
    with SingleTickerProviderStateMixin {
  /// The pull in logical pixels (display value, rubber-band applied).
  final ValueNotifier<double> offset = ValueNotifier<double>(0);

  /// The sheet's translation as a share of its own height: 0 at rest, 1 when
  /// its top edge is where its bottom edge was. Unbounded: a spring overshoots.
  late final AnimationController _ctl =
      AnimationController.unbounded(vsync: this)..addListener(_onTick);

  /// One instance for the host's life: a fresh one per build would read as
  /// a configuration change to every scroll view under it.
  late final ScrollPhysics _physics = SheetPullPhysics._(this);

  /// The finger's own travel in px, before the rubber band.
  double _raw = 0;
  bool _dragging = false;
  bool _exiting = false;
  bool _popping = false;
  ModalRoute<dynamic>? _route;

  bool get dragging => _dragging;

  double get _height {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : 0;
  }

  double get _offscreen {
    final h = _height;
    return h <= 0 ? 2 : 1 + widget.offscreenExtra / h;
  }

  bool get _canPull {
    if (!widget.enabled || _popping || _exiting) return false;
    final route = ModalRoute.of(context);
    return route == null ||
        route.popDisposition != RoutePopDisposition.doNotPop;
  }

  bool get _calm => MotionScope.of(context).calm;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.animation?.removeStatusListener(_onRouteStatus);
      _route = route;
      if (widget.animateIn) route?.animation?.addStatusListener(_onRouteStatus);
    }
    if (!_started) {
      _started = true;
      if (widget.animateIn && !_calm) {
        // Off screen for the first frame (the real distance needs a layout),
        // then sprung in from just past the screen edge.
        _ctl.value = 2;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _exiting || _dragging) return;
          _ctl.value = _offscreen;
          _springTo(0, _kPresentSpring, 0);
        });
      }
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && !_exiting) {
      _exit(_ctl.isAnimating ? _ctl.velocity : 0);
    }
  }

  void _onTick() {
    offset.value = _ctl.value * _height;
  }

  void _springTo(double target, SpringDescription spring, double velocity) {
    _ctl
        .animateWith(SpringSimulation(spring, _ctl.value, target, velocity))
        // A spring only comes within tolerance of its target; land exactly,
        // so "at rest" is 0.0 and not 0.014px of ringing.
        .then((_) {
      if (mounted) _ctl.value = target;
    });
  }

  void _beginDrag() {
    if (_dragging) return;
    _ctl.stop();
    _dragging = true;
    _raw = _ctl.value * _height;
  }

  void _apply() {
    final h = _height;
    if (h <= 0) return;
    final shown = _raw < 0 ? _raw * _kRubberBand : _raw;
    _ctl.value = shown / h;
  }

  /// The finger moved [dy] further down past the body's top.
  void pull(double dy) {
    if (!_canPull) return;
    _beginDrag();
    _raw = math.max(0, _raw + dy);
    _apply();
  }

  /// The finger moved [dy] back up while the sheet is pulled; returns how
  /// much of it the sheet took (the rest scrolls the body).
  double giveBack(double dy) {
    if (offset.value <= 0) return 0;
    _beginDrag();
    final take = math.min(dy, math.max(0.0, _raw));
    if (take > 0) {
      _raw -= take;
      _apply();
    }
    return take;
  }

  /// The finger lifted, moving down at [velocity] logical px/s.
  void release(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    final h = _height;
    final pulled = _ctl.value * h;
    if (pulled <= 0) {
      if (_ctl.value < 0) _springBack(velocity * _kRubberBand);
      return;
    }
    final far = h > 0 && pulled > h * _kDismissFraction;
    if (far || velocity > _kDismissVelocity) {
      _dismiss(velocity);
    } else {
      _springBack(velocity);
    }
  }

  Future<void> _dismiss(double velocity) async {
    _popping = true;
    _exit(velocity / math.max(1, _height));
    final popped = await Navigator.of(context).maybePop();
    if (!mounted) return;
    if (!popped) {
      _popping = false;
      _exiting = false;
      _springBack(0);
    }
  }

  /// Off the screen, carrying [velocity] (in sheet-heights per second).
  void _exit(double velocity) {
    _exiting = true;
    if (_calm) {
      _ctl.value = _offscreen;
      return;
    }
    _springTo(_offscreen, _kExitSpring, velocity);
  }

  void _springBack(double velocity) {
    if (_calm) {
      _ctl.value = 0;
      return;
    }
    _springTo(0, _kPresentSpring, velocity / math.max(1, _height));
  }

  void _onDragStart(DragStartDetails d) {
    if (!_canPull) return;
    _beginDrag();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    _raw += d.delta.dy;
    _apply();
  }

  void _onDragEnd(DragEndDetails d) => release(d.primaryVelocity ?? 0);

  void _onDragCancel() => release(0);

  @override
  void dispose() {
    _route?.animation?.removeStatusListener(_onRouteStatus);
    _ctl.dispose();
    offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body = widget.child;
    if (widget.enabled) {
      body = ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(physics: _physics),
        // The drag can end without the pull physics' ballistic hand-off: a
        // scroll view whose own physics override the ballistic (clamping
        // does), a disposed scrollable, a cancelled pointer. The end of the
        // scroll settles the sheet either way, with the finger's speed when
        // a drag ended it.
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (n) {
            if (_dragging) release(n.dragDetails?.primaryVelocity ?? 0);
            return false;
          },
          // An `ExpandingSheet` dragged down to nothing closes the route.
          child: NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              if (n.extent <= n.minExtent &&
                  n.shouldCloseOnMinExtent &&
                  !_exiting &&
                  _canPull) {
                Navigator.of(context).maybePop();
              }
              return false;
            },
            child: GestureDetector(
              // A pure touch gesture. Left in the semantics tree, the drag
              // handler becomes a semantic boundary that swallows its
              // children's nodes: the bar's Back/Close buttons lose their
              // labels (merged into one scrollable "button"). Screen-reader
              // users dismiss through the barrier's Dismiss action instead.
              excludeFromSemantics: true,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              onVerticalDragCancel: _onDragCancel,
              child: body,
            ),
          ),
        ),
      );
    }
    return _SheetDragScope(
      host: this,
      // Always the translation, even at rest: swapping it in and out would
      // change the tree's shape and remount the whole sheet mid-gesture.
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(0, _ctl.value),
          child: child,
        ),
        child: body,
      ),
    );
  }
}

class _SheetDragScope extends InheritedWidget {
  const _SheetDragScope({required this.host, required super.child});

  final _SheetDragHostState host;

  ValueListenable<double> get offset => host.offset;

  static _SheetDragHostState? hostOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SheetDragScope>()?.host;

  static _SheetDragScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SheetDragScope>();

  @override
  bool updateShouldNotify(_SheetDragScope old) => old.host != host;
}

/// THE scrolling body of a sheet: a [SingleChildScrollView] whose drag, once
/// the content is at its top, pulls the whole sheet down — and closes it past
/// 40% of its height or on a flick. Scrolled down, a downward drag
/// scrolls the content back first, exactly like iOS. (Any vertical scroll
/// view in a compact sheet does this, through the host; this one is the
/// ready-made body.)
///
/// Clamping, not bouncing: a bounce at the top would eat the very pixels
/// that should move the sheet. Outside a compact sheet (the desktop popover,
/// a test with no host) it is an ordinary scroll view.
///
/// Put it as the [SheetFrame] child (or under a `SheetBar` in a sheet that
/// owns its layout); the handle and bar keep `BottomSheet`'s own drag.
class SheetScrollBody extends StatelessWidget {
  const SheetScrollBody({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final Widget child;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: padding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      physics: SheetPullPhysics.of(context),
      child: child,
    );
  }
}

/// The physics of a [SheetScrollBody], and of every other vertical scroll
/// view in a compact sheet (the host supplies them). Horizontal scroll views
/// pass through untouched.
class SheetPullPhysics extends ClampingScrollPhysics {
  const SheetPullPhysics._(this._host, {super.parent});

  final _SheetDragHostState _host;

  /// The pull physics for a scroll view inside a compact sheet, or plain
  /// clamping physics anywhere else.
  static ScrollPhysics of(BuildContext context) {
    final host = _SheetDragScope.hostOf(context);
    return host == null
        ? const ClampingScrollPhysics()
        : SheetPullPhysics._(host);
  }

  @override
  SheetPullPhysics applyTo(ScrollPhysics? ancestor) =>
      SheetPullPhysics._(_host, parent: buildParent(ancestor));

  // `offset` is in scroll terms: positive moves towards minScrollExtent. On
  // an ordinary list that is the finger moving DOWN; on a reversed one
  // (newest at the bottom) it is the finger moving up, and the screen's top
  // of the content is maxScrollExtent.
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.axis != Axis.vertical) {
      return super.applyPhysicsToUserOffset(position, offset);
    }
    final reversed = axisDirectionIsReversed(position.axisDirection);
    final down = reversed ? -offset : offset;
    final atTop = reversed
        ? position.pixels >= position.maxScrollExtent
        : position.pixels <= position.minScrollExtent;
    if (down > 0 && atTop) {
      _host.pull(down);
      if (_host.dragging) return 0;
    } else if (down < 0 && _host.offset.value > 0) {
      final took = _host.giveBack(-down);
      final rest = down + took;
      return super.applyPhysicsToUserOffset(
        position,
        reversed ? -rest : rest,
      );
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  // `velocity` is in scroll terms: positive scrolls forward, which on an
  // ordinary list is the finger moving UP, so the finger's downward speed
  // is its negation (and on a reversed list, the velocity itself).
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (_host.dragging && position.axis == Axis.vertical) {
      final pulled = _host.offset.value > 0;
      _host.release(
        axisDirectionIsReversed(position.axisDirection) ? velocity : -velocity,
      );
      if (pulled) return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
