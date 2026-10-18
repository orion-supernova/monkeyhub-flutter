import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart' show DeviceGestureSettings, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/services.dart';

import '../../keyboard/focusable_tap.dart';
import '../../theme/motion.dart';

/// The two pictures of a video call, one full-bleed and one in a corner,
/// and every move between them.
///
/// The old screen swapped which renderer each view showed: a tap on the
/// corner tile and the two pictures changed places in one frame. Here each
/// picture is ONE widget that keeps its place in the tree and moves, the
/// way the video-note preview flies (never two lookalikes swapped):
///
///  * **Swap.** The tile you tapped grows out of its corner into the
///    screen, its corners straightening as it goes, overshooting the edges
///    a touch and settling. The moment it covers the screen, the picture
///    it covered springs into the corner it left. Nothing ever shows black.
///  * **Their video lands** (you were full-screen while it rang): your
///    picture shrinks into the corner on a spring while theirs fades in
///    under it, WhatsApp's moment, now a motion instead of a cut.
///  * **A tile arrives** (a camera comes on): it pops into its corner.
///  * **Drag** the tile anywhere; it lifts under the finger, and on release
///    springs to the nearest corner, carrying the fling into the spring so
///    a flick lands where it was thrown. When the chrome hides, the tile
///    glides into the room it leaves (FaceTime's tile does the same).
///
/// Cheap by construction: the two pictures are built by the caller once
/// per change and handed in, so a frame of any of these moves re-lays two
/// [Positioned]s and re-clips them; it never rebuilds a video view. Calm
/// motion snaps every move.
class CallPipStage extends StatefulWidget {
  const CallPipStage({
    super.key,
    this.main,
    this.pip,
    this.swapped = false,
    this.onPipTap,
    this.pipSemanticLabel,
    required this.top,
    required this.bottom,
    this.margin = 16,
  });

  /// The picture that fills the screen: the other person. Null before it
  /// exists, and [pip] fills the screen instead.
  final Widget? main;

  /// The corner picture: yourself. Null while your camera is off.
  final Widget? pip;

  /// [pip] full-screen and [main] in the corner. Ignored unless both exist.
  final bool swapped;

  /// A tap on the corner tile. Null: the tile only drags.
  final VoidCallback? onPipTap;
  final String? pipSemanticLabel;

  /// The band the corner tile keeps clear of: the name block above it and
  /// the tray below. Changes glide.
  final double top;
  final double bottom;
  final double margin;

  /// The corner tile's size for a stage of [area]: a camera's shape in the
  /// screen's orientation, about a quarter of the short side.
  static Size pipSizeFor(Size area) {
    final short = area.shortestSide;
    if (area.height >= area.width) {
      final w = (short * 0.28).clamp(96.0, 200.0);
      return Size(w, w * 1.4);
    }
    final h = (short * 0.30).clamp(80.0, 200.0);
    return Size(h * 1.4, h);
  }

  /// The corner tile's rounding at [size]: concentric with the device's
  /// own corners on a phone, never a sharp card.
  static double pipRadiusFor(Size size) =>
      (size.shortestSide * 0.17).clamp(14.0, 24.0);

  @override
  State<CallPipStage> createState() => _CallPipStageState();
}

/// Where one picture is.
enum _Spot { none, full, pip }

/// The move in flight.
enum _Move { none, swap, shrink, grow, pop }

/// The grow of a swap: out of the corner, past the screen's edges by about
/// 4%, and back. A cubic whose second handle sits above 1 overshoots once
/// and comes back down without ever dipping under the edges again, so the
/// picture under it is covered from the moment it first reaches them.
const Curve _growCurve = Cubic(0.22, 0.0, 0.0, 1.3);

/// When [_growCurve] first reaches the edges.
final double _growCovers = () {
  for (var i = 1; i <= 200; i++) {
    final t = i / 200;
    if (_growCurve.transform(t) >= 1) return t;
  }
  return 1.0;
}();

class _CallPipStageState extends State<CallPipStage>
    with TickerProviderStateMixin {
  /// Where each picture was before the move in flight, and is now.
  _Spot _mainFrom = _Spot.none;
  _Spot _pipFrom = _Spot.none;

  _Move _move = _Move.none;

  /// 0 → 1 across [_move].
  late final AnimationController _flight = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _move = _Move.none);
      }
    });

  /// The corner the tile rests in: x and y each -1 or 1. Top-right, where
  /// it has always been.
  Offset _corner = const Offset(1, -1);

  /// The tile's top-left while dragged or settling; null at rest.
  Offset? _live;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  late final AnimationController _settle =
      AnimationController.unbounded(vsync: this)
        ..addListener(() {
          setState(() => _live = Offset.lerp(_from, _to, _settle.value));
        });

  /// 1 while a finger holds the tile: it lifts, a little bigger, a deeper
  /// shadow.
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 260),
  );

  bool _dragging = false;

  /// The stage's size at the last layout, for moves that start outside one.
  Size _area = Size.zero;

  bool get _calm => MotionScope.of(context).calm;

  _Spot _mainSpot(CallPipStage w) {
    if (w.main == null) return _Spot.none;
    if (w.pip == null) return _Spot.full;
    return w.swapped ? _Spot.pip : _Spot.full;
  }

  _Spot _pipSpot(CallPipStage w) {
    if (w.pip == null) return _Spot.none;
    if (w.main == null) return _Spot.full;
    return w.swapped ? _Spot.full : _Spot.pip;
  }

  @override
  void initState() {
    super.initState();
    _mainFrom = _mainSpot(widget);
    _pipFrom = _pipSpot(widget);
  }

  @override
  void didUpdateWidget(CallPipStage old) {
    super.didUpdateWidget(old);
    final mainWas = _mainSpot(old);
    final pipWas = _pipSpot(old);
    final mainNow = _mainSpot(widget);
    final pipNow = _pipSpot(widget);
    if (mainWas != mainNow || pipWas != pipNow) {
      _begin(mainWas, pipWas, mainNow, pipNow);
    }
    if ((old.top != widget.top || old.bottom != widget.bottom) &&
        !_dragging &&
        !_area.isEmpty) {
      _glideTo(
        _cornerOrigin(_area, _corner, top: old.top, bottom: old.bottom),
        _cornerOrigin(_area, _corner),
        0,
      );
    }
  }

  void _begin(_Spot mainWas, _Spot pipWas, _Spot mainNow, _Spot pipNow) {
    _Move move;
    Duration duration;
    if (mainWas == _Spot.full && mainNow == _Spot.pip ||
        mainWas == _Spot.pip && mainNow == _Spot.full) {
      move = _Move.swap;
      duration = const Duration(milliseconds: 520);
    } else if (pipWas == _Spot.full && pipNow == _Spot.pip) {
      move = _Move.shrink;
      duration = const Duration(milliseconds: 560);
    } else if (pipWas == _Spot.pip && pipNow == _Spot.full ||
        mainWas == _Spot.pip && mainNow == _Spot.full) {
      move = _Move.grow;
      duration = const Duration(milliseconds: 440);
    } else if (pipNow == _Spot.pip && pipWas == _Spot.none ||
        mainNow == _Spot.pip && mainWas == _Spot.none) {
      move = _Move.pop;
      duration = const Duration(milliseconds: 420);
    } else {
      move = _Move.none;
      duration = Duration.zero;
    }
    _mainFrom = mainWas;
    _pipFrom = pipWas;
    if (move == _Move.none || _calm) {
      _move = _Move.none;
      _flight.value = 1;
      return;
    }
    _move = move;
    _flight
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _flight.dispose();
    _settle.dispose();
    _lift.dispose();
    super.dispose();
  }

  Offset _cornerOrigin(
    Size area,
    Offset corner, {
    double? top,
    double? bottom,
  }) {
    final size = CallPipStage.pipSizeFor(area);
    final m = widget.margin;
    final x = corner.dx < 0 ? m : area.width - size.width - m;
    final y = corner.dy < 0
        ? (top ?? widget.top)
        : area.height - size.height - (bottom ?? widget.bottom);
    return Offset(x, y);
  }

  Rect _pipRect(Size area) {
    final at = _live ?? _cornerOrigin(area, _corner);
    return at & CallPipStage.pipSizeFor(area);
  }

  /// Springs the tile from [from] to [to], starting at [speed] path-lengths
  /// per second.
  void _glideTo(Offset from, Offset to, double speed) {
    final distance = (to - from).distance;
    if (distance < 1 || _calm) {
      _settle.stop();
      setState(() => _live = null);
      return;
    }
    _from = from;
    _to = to;
    _settle
        .animateWith(
          SpringSimulation(
            const SpringDescription(mass: 1, stiffness: 320, damping: 27),
            0,
            1,
            speed,
          ),
        )
        .then((_) {
      if (mounted && !_dragging) setState(() => _live = null);
    });
  }

  void _onPanStart(DragStartDetails d) {
    _settle.stop();
    // A grab mid-move lands the move first: the tile is where it rests.
    if (_flight.isAnimating) {
      _flight.value = 1;
      _move = _Move.none;
    }
    _dragging = true;
    _live ??= _cornerOrigin(_area, _corner);
    if (!_calm) _lift.forward();
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _live = (_live ?? _cornerOrigin(_area, _corner)) + d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    _dragging = false;
    if (!_calm) _lift.reverse();
    final area = _area;
    final at = _live ?? _cornerOrigin(area, _corner);
    final v = d.velocity.pixelsPerSecond;
    // Project the fling a fifth of a second ahead and pick the corner it is
    // heading for: a flick across the screen should cross the screen.
    final size = CallPipStage.pipSizeFor(area);
    final centre = at + v * 0.2 + Offset(size.width / 2, size.height / 2);
    final next = Offset(
      centre.dx < area.width / 2 ? -1 : 1,
      centre.dy < area.height / 2 ? -1 : 1,
    );
    if (next != _corner) HapticFeedback.lightImpact();
    _corner = next;
    final to = _cornerOrigin(area, next);
    final distance = (to - at).distance;
    final along = distance < 1 ? Offset.zero : (to - at) / distance;
    final speed =
        distance < 1 ? 0.0 : (v.dx * along.dx + v.dy * along.dy) / distance;
    _glideTo(at, to, speed);
  }

  void _onTap() {
    if (_flight.isAnimating) return;
    widget.onPipTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _area = box.biggest;
        return AnimatedBuilder(
          animation: Listenable.merge([_flight, _lift]),
          builder: (context, _) => _stage(_area),
        );
      },
    );
  }

  Widget _stage(Size area) {
    final full = Offset.zero & area;
    final pip = _pipRect(area);
    final pipSize = CallPipStage.pipSizeFor(area);
    final radius = CallPipStage.pipRadiusFor(pipSize);
    final t = _move == _Move.none ? 1.0 : _flight.value;
    final mainNow = _mainSpot(widget);
    final pipNow = _pipSpot(widget);

    // Each picture's frame this tick: where, how round, how opaque, how
    // big around its centre, and whether it is the one on top.
    _Frame frameFor(_Spot from, _Spot now) {
      switch (_move) {
        case _Move.swap:
          if (now == _Spot.full) {
            // The tapped tile grows out of its corner.
            final v = _growCurve.transform(t);
            return _Frame(
              _lerpRect(pip, full, v),
              radius * (1 - v.clamp(0.0, 1.0)),
              top: t < _growCovers,
              shadow: 1 - v.clamp(0.0, 1.0),
            );
          }
          // The covered picture: still full under the grower until that
          // covers the screen, then springing into the corner.
          if (t < _growCovers) return _Frame(full, 0, top: false);
          final p = _span(t, _growCovers, 1);
          return _Frame(
            pip,
            radius,
            top: true,
            scale: 0.55 + 0.45 * Curves.easeOutBack.transform(p),
            opacity: Curves.easeOut.transform((p * 2.4).clamp(0.0, 1.0)),
            shadow: 1,
          );
        case _Move.shrink:
          if (now == _Spot.pip) {
            final v = Curves.easeOutBack.transform(t);
            return _Frame(
              _lerpRect(full, pip, v),
              radius * v.clamp(0.0, 1.0),
              top: true,
              shadow: v.clamp(0.0, 1.0),
            );
          }
          // Theirs arriving under it.
          return _Frame(
            full,
            0,
            top: false,
            opacity: Curves.easeOut.transform(t),
          );
        case _Move.grow:
          if (now == _Spot.full && from == _Spot.pip) {
            final v = Curves.easeOutCubic.transform(t);
            return _Frame(
              _lerpRect(pip, full, v),
              radius * (1 - v),
              top: true,
              shadow: 1 - v,
            );
          }
        case _Move.pop:
          if (now == _Spot.pip && from == _Spot.none) {
            return _Frame(
              pip,
              radius,
              top: true,
              scale: 0.5 + 0.5 * Curves.easeOutBack.transform(t),
              opacity: Curves.easeOut.transform((t * 2).clamp(0.0, 1.0)),
              shadow: 1,
            );
          }
        case _Move.none:
          break;
      }
      return now == _Spot.full
          ? _Frame(full, 0, top: false)
          : _Frame(pip, radius, top: true, shadow: 1);
    }

    final layers = <(_Frame, Widget)>[];
    final main = widget.main;
    final pipChild = widget.pip;
    if (main != null && mainNow != _Spot.none) {
      final f = frameFor(_mainFrom, mainNow);
      layers.add((f, _layer(const ValueKey('main'), f, main, mainNow)));
    }
    if (pipChild != null && pipNow != _Spot.none) {
      final f = frameFor(_pipFrom, pipNow);
      layers.add((f, _layer(const ValueKey('pip'), f, pipChild, pipNow)));
    }
    // The one on top last. Keyed, so a reorder moves the elements (and the
    // video views in them) rather than rebuilding them.
    layers.sort((a, b) => (a.$1.top ? 1 : 0).compareTo(b.$1.top ? 1 : 0));
    return Stack(
      fit: StackFit.expand,
      children: [for (final l in layers) l.$2],
    );
  }

  static Rect _lerpRect(Rect a, Rect b, double t) => Rect.fromLTRB(
        lerpDouble(a.left, b.left, t)!,
        lerpDouble(a.top, b.top, t)!,
        lerpDouble(a.right, b.right, t)!,
        lerpDouble(a.bottom, b.bottom, t)!,
      );

  Widget _layer(Key key, _Frame f, Widget child, _Spot spot) {
    final lift = _dragging || _lift.value > 0 ? _lift.value : 0.0;
    final isTile = spot == _Spot.pip;
    final scale = f.scale * (isTile ? 1 + 0.05 * lift : 1);
    Widget body = ClipRRect(
      borderRadius: BorderRadius.circular(f.radius),
      clipBehavior: f.radius <= 0.01 ? Clip.none : Clip.antiAlias,
      child: child,
    );
    if (f.shadow > 0.01) {
      // The tile's edge against a picture of the same colours: a deep soft
      // shadow under it and a hairline rim drawn over it.
      body = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(f.radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: (0.38 + 0.14 * lift) * f.shadow,
              ),
              blurRadius: 18 + 14 * lift,
              offset: Offset(0, 4 + 6 * lift),
            ),
          ],
        ),
        position: DecorationPosition.background,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(f.radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16 * f.shadow),
              width: 0.8,
            ),
          ),
          child: body,
        ),
      );
    }
    if (scale != 1) {
      body = Transform.scale(scale: scale, child: body);
    }
    if (f.opacity < 1) {
      body = Opacity(opacity: f.opacity.clamp(0.0, 1.0), child: body);
    }
    if (isTile) {
      body = FocusableTap(
        onTap: widget.onPipTap == null ? null : _onTap,
        semanticLabel: widget.pipSemanticLabel,
        shape: FocusRingShape.rounded,
        radius: f.radius,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPipTap == null ? null : _onTap,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: body,
        ),
      );
      // The tile's pan must beat the screen's own vertical flick (which
      // shows and hides the chrome): a pan claims at twice the touch slop
      // and a vertical drag at once, so a straight up-or-down drag of the
      // tile went to the screen and the tile only moved sideways. A third
      // of the slop here makes the pan claim first.
      final mq = MediaQuery.of(context);
      final slop = mq.gestureSettings.touchSlop ?? kTouchSlop;
      body = MediaQuery(
        data: mq.copyWith(
          gestureSettings: DeviceGestureSettings(touchSlop: slop / 3),
        ),
        child: body,
      );
    } else {
      // The full picture takes no gesture: a tap on it falls through to the
      // screen's show/hide-the-chrome tap.
      body = IgnorePointer(child: body);
    }
    return Positioned.fromRect(key: key, rect: f.rect, child: body);
  }
}

double _span(double t, double from, double to) =>
    to <= from ? 1.0 : ((t - from) / (to - from)).clamp(0.0, 1.0);

@immutable
class _Frame {
  const _Frame(
    this.rect,
    this.radius, {
    required this.top,
    this.scale = 1,
    this.opacity = 1,
    this.shadow = 0,
  });

  final Rect rect;
  final double radius;
  final bool top;
  final double scale;
  final double opacity;

  /// 0..1, the tile's shadow and rim: on in the corner, gone full-screen.
  final double shadow;
}

/// Exposed so tests can step a swap and check nothing is ever uncovered.
@visibleForTesting
double get callPipGrowCovers => _growCovers;

@visibleForTesting
double callPipGrowAt(double t) => _growCurve.transform(t);
