import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

/// The host of a sheet's pull: translates the sheet by the drag, decides on
/// release whether to close it or spring it home. `showAdaptiveSheet` wraps
/// every compact sheet in one; nothing else should.
///
/// [enabled] false (a sheet presented with `enableDrag: false` or
/// `isDismissible: false`) makes the body an ordinary scroll view. A sheet
/// under a `PopScope(canPop: false)` ignores the pull too.
class SheetDragHost extends StatefulWidget {
  const SheetDragHost({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  /// How far the nearest host has pulled its sheet down, in logical pixels —
  /// for tests and for a body that wants to react to the pull. Null outside
  /// a compact sheet (the desktop popover has no host).
  static ValueListenable<double>? offsetOf(BuildContext context) =>
      _SheetDragScope.maybeOf(context)?.offset;

  @override
  State<SheetDragHost> createState() => _SheetDragHostState();
}

/// Past this share of the sheet's height, a release closes it.
const double _kDismissFraction = 0.25;

/// A downward release faster than this (logical px/s) closes it whatever the
/// distance — the flick.
const double _kDismissVelocity = 700;

class _SheetDragHostState extends State<SheetDragHost>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> offset = ValueNotifier<double>(0);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(_onSettleTick);

  /// One instance for the host's life: a fresh one per build would read as
  /// a configuration change to every scroll view under it.
  late final ScrollPhysics _physics = SheetPullPhysics._(this);

  double _settleFrom = 0;
  bool _dragging = false;
  bool _popping = false;

  bool get dragging => _dragging;

  bool get _canPull {
    if (!widget.enabled || _popping) return false;
    final route = ModalRoute.of(context);
    return route == null ||
        route.popDisposition != RoutePopDisposition.doNotPop;
  }

  /// The finger moved [dy] further down past the body's top.
  void pull(double dy) {
    if (!_canPull) return;
    _settle.stop();
    _dragging = true;
    offset.value = math.max(0, offset.value + dy);
  }

  /// The finger moved [dy] back up while the sheet is pulled; returns how
  /// much of it the sheet took (the rest scrolls the body).
  double giveBack(double dy) {
    final take = math.min(dy, offset.value);
    if (take > 0) offset.value -= take;
    return take;
  }

  /// The finger lifted, moving down at [velocity] logical px/s.
  void release(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    final pulled = offset.value;
    if (pulled <= 0) return;
    final height = context.size?.height ?? 0;
    final far = height > 0 && pulled > height * _kDismissFraction;
    if (far || velocity > _kDismissVelocity) {
      _dismiss();
    } else {
      _springBack();
    }
  }

  Future<void> _dismiss() async {
    _popping = true;
    // The route's own exit slides the sheet the rest of the way down from
    // where the finger left it; the translation simply rides along.
    final popped = await Navigator.of(context).maybePop();
    if (!mounted) return;
    if (!popped) {
      _popping = false;
      _springBack();
    }
  }

  void _springBack() {
    if (MotionScope.of(context).calm) {
      offset.value = 0;
      return;
    }
    _settleFrom = offset.value;
    _settle.forward(from: 0);
  }

  void _onSettleTick() {
    offset.value =
        _settleFrom * (1 - Curves.easeOutCubic.transform(_settle.value));
  }

  @override
  void dispose() {
    _settle.dispose();
    offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body = widget.child;
    if (widget.enabled) {
      body = ScrollConfiguration(
        behavior: ScrollConfiguration.of(context)
            .copyWith(physics: _physics),
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
          child: body,
        ),
      );
    }
    return _SheetDragScope(
      host: this,
      // Always the Transform, even at rest: swapping it in and out would
      // change the tree's shape and remount the whole sheet mid-gesture.
      child: ValueListenableBuilder<double>(
        valueListenable: offset,
        builder: (context, dy, child) => Transform.translate(
          offset: Offset(0, dy),
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
/// a quarter of its height or on a flick. Scrolled down, a downward drag
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
