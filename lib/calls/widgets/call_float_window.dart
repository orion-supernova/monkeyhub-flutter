import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DeviceGestureSettings, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/motion.dart';
import '../call_float.dart';
import '../call_pip.dart';
import 'call_pip_stage.dart';
import 'call_video_fit.dart';
import 'system_pip_view.dart' show CallPipNameCard;

/// The floating call window [CallFloat] keeps over every screen while a
/// call is minimized. The call screen's corner tile, let out of the screen:
/// the same frame, lift, spring and moves ([CallPipStage]).
///
///  * **Minimize.** The picture the call screen was showing flies out of
///    the screen into a corner, its corners rounding as it goes, while the
///    screen fades from under it (from its tile, in a group grid).
///  * **Tap** it and it grows back into the screen, which arrives under it
///    in one frame; it hands over once the screen has its picture.
///  * **Drag** it to any corner: it lifts under the finger and springs to
///    the corner a release is heading for. It keeps clear of the status
///    and navigation bars, the tab bar and the composer, and of the
///    keyboard as that comes up.
///  * **Fling** it off the side and it is tucked: the call goes to the bar
///    at the top until its screen is next opened.
///  * It **pops** in when a picture turns up while the call is minimized
///    (a camera coming on), and out when there is no longer one.
///
/// Shaped like its picture (a phone's portrait camera, a laptop's or a
/// shared screen's landscape), and it reshapes on a glide when that turns.
/// Calm motion snaps every move. Nothing here runs while it is not up.
class CallFloatWindow extends StatefulWidget {
  const CallFloatWindow({super.key, CallFloat? float}) : _float = float;

  final CallFloat? _float;

  /// The window's size for a picture of [aspect] (width over height) in a
  /// screen of [area]: about the corner tile's area whatever the shape, so
  /// a landscape picture is as big as a portrait one, not a sliver.
  static Size sizeFor(Size area, double aspect) {
    final w0 = (area.shortestSide * 0.30).clamp(104.0, 220.0);
    final px = w0 * w0 * 1.4;
    final a = aspect.clamp(9 / 16, 16 / 9);
    return Size(math.sqrt(px * a), math.sqrt(px / a));
  }

  @override
  State<CallFloatWindow> createState() => _CallFloatWindowState();
}

enum _Move { none, launch, pop, grow, held, handoff, out, tuck }

class _CallFloatWindowState extends State<CallFloatWindow>
    with TickerProviderStateMixin {
  CallFloat get _float => widget._float ?? CallFloat.instance;

  /// The corner it rests in, kept across minimizes: x and y each -1 or 1.
  /// Top-right to start, clear of a chat's composer and the tab bar.
  static Offset _corner = const Offset(1, -1);

  bool _shown = false;
  _Move _move = _Move.none;

  /// 0 → 1 across [_move].
  late final AnimationController _flight = AnimationController(vsync: this)
    ..addStatusListener(_onFlightStatus);

  /// Where a launch flies from.
  Rect _from = Rect.zero;

  /// The left edge a tuck leaves from and goes to.
  double _tuckFrom = 0;
  double _tuckTo = 0;

  /// The window's top-left while dragged or settling; null at rest.
  Offset? _live;
  Offset _settleFrom = Offset.zero;
  Offset _settleTo = Offset.zero;
  late final AnimationController _settle =
      AnimationController.unbounded(vsync: this)
        ..addListener(() {
          setState(() {
            _live = Offset.lerp(_settleFrom, _settleTo, _settle.value);
          });
        });

  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 260),
  );

  /// The picture's shape, gliding from [_aspectFrom] to [_aspectTo].
  double _aspectFrom = 3 / 4;
  double _aspectTo = 3 / 4;
  late final AnimationController _reshape = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  bool _dragging = false;
  Size _area = Size.zero;
  Offset? _lastRest;

  /// The last picture shown, for the frames of a pop-out after it is gone.
  CallPipSpec? _lastSpec;

  bool get _calm => MotionScope.of(context).calm;

  @override
  void initState() {
    super.initState();
    _float.addListener(_onFloat);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFloat());
  }

  @override
  void dispose() {
    _float.removeListener(_onFloat);
    _flight.dispose();
    _settle.dispose();
    _lift.dispose();
    _reshape.dispose();
    super.dispose();
  }

  double get _aspect => _lerpAspect(
        Curves.easeOutCubic.transform(_reshape.value),
      );

  double _lerpAspect(double t) => _aspectFrom + (_aspectTo - _aspectFrom) * t;

  /// The shape the window should take; null keeps the one it has (a
  /// picture re-binding, as the app comes back, has no size for a beat).
  double? _targetAspect() {
    final spec = _float.spec ?? _lastSpec;
    if (spec == null) return null;
    if (spec.videoOff || spec.trackId == null) return 3 / 4;
    final v = _float.videoSize;
    if (v == null || v.isEmpty) return null;
    return v.width / v.height;
  }

  void _onFloat() {
    if (!mounted) return;
    final spec = _float.spec;
    if (spec != null) _lastSpec = spec;
    final vis = _float.visible;
    if (vis && !_shown) {
      _appear();
    } else if (!vis && _shown && _move != _Move.out && _move != _Move.tuck) {
      _disappear();
    }
    if (_float.handoffLanded && _move == _Move.held) _run(_Move.handoff, 180);
    final a = _targetAspect();
    if (a != null && (a - _aspectTo).abs() > 0.01) {
      if (!_shown || _calm) {
        _aspectFrom = _aspectTo = a;
        _reshape.value = 1;
      } else {
        _aspectFrom = _aspect;
        _aspectTo = a;
        _reshape.forward(from: 0);
      }
    }
    setState(() {});
  }

  void _run(_Move move, int ms) {
    _move = move;
    if (_calm) {
      _flight.value = 1;
      _onFlightStatus(AnimationStatus.completed);
      return;
    }
    _flight
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  void _appear() {
    _shown = true;
    _live = null;
    _settle.stop();
    _aspectFrom = _aspectTo = _targetAspect() ?? _aspectTo;
    _reshape.value = 1;
    final from = _float.takeLaunchFrom();
    if (from != null && !from.isEmpty) {
      _from = from;
      _run(_Move.launch, 560);
    } else {
      _run(_Move.pop, 420);
    }
  }

  void _disappear() {
    _settle.stop();
    _run(_Move.out, 200);
  }

  void _onFlightStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed || !mounted) return;
    switch (_move) {
      case _Move.grow:
        setState(() => _move = _Move.held);
        _float.expand();
      case _Move.handoff:
        setState(() {
          _shown = false;
          _move = _Move.none;
          _live = null;
        });
        _float.endHandoff();
      case _Move.out:
        setState(() {
          _shown = false;
          _move = _Move.none;
          _live = null;
        });
      case _Move.tuck:
        setState(() {
          _shown = false;
          _move = _Move.none;
          _live = null;
        });
        _float.tuck();
      case _Move.launch:
      case _Move.pop:
        setState(() => _move = _Move.none);
      case _Move.none:
      case _Move.held:
        break;
    }
  }

  /// Top and bottom of the band the window rests in.
  EdgeInsets _band(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pad = mq.padding;
    return EdgeInsets.fromLTRB(
      pad.left + 12,
      // Under a page's bar.
      pad.top + 56,
      pad.right + 12,
      // Over the tab bar and a chat's composer; over the keyboard while it
      // is up.
      math.max(pad.bottom + 76, mq.viewInsets.bottom + 12),
    );
  }

  Size get _size => CallFloatWindow.sizeFor(_area, _aspect);

  Offset _restOrigin(EdgeInsets band, Offset corner) {
    final size = _size;
    final x = corner.dx < 0 ? band.left : _area.width - size.width - band.right;
    final y = corner.dy < 0
        ? band.top
        : _area.height - size.height - band.bottom;
    return Offset(x, y);
  }

  void _glideTo(Offset from, Offset to, double speed) {
    final distance = (to - from).distance;
    if (distance < 1 || _calm) {
      _settle.stop();
      setState(() => _live = null);
      return;
    }
    _settleFrom = from;
    _settleTo = to;
    _settle
        .animateWith(SpringSimulation(kCallTileSpring, 0, 1, speed))
        .then((_) {
      if (mounted && !_dragging) setState(() => _live = null);
    });
  }

  bool get _settled =>
      _move == _Move.none || _move == _Move.launch || _move == _Move.pop;

  void _onPanStart(DragStartDetails d) {
    if (!_settled) return;
    _settle.stop();
    // A grab mid-flight lands the flight first: the window is where it
    // rests.
    if (_flight.isAnimating) {
      _flight.value = 1;
      _move = _Move.none;
    }
    _dragging = true;
    _live ??= _restOrigin(_band(context), _corner);
    if (!_calm) _lift.forward();
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    setState(() => _live = _live! + d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    if (!_calm) _lift.reverse();
    final band = _band(context);
    final at = _live ?? _restOrigin(band, _corner);
    final size = _size;
    final v = d.velocity.pixelsPerSecond;
    // Project the release a fifth of a second ahead: a flick across the
    // screen crosses it, and one off the side goes off it.
    final centre = at + v * 0.2 + Offset(size.width / 2, size.height / 2);
    final offLeft = centre.dx < 0 || at.dx < -size.width * 0.45;
    final offRight = centre.dx > _area.width ||
        at.dx + size.width > _area.width + size.width * 0.45;
    if (offLeft || offRight) {
      HapticFeedback.lightImpact();
      _tuckFrom = at.dx;
      _tuckTo = offLeft ? -size.width - 24 : _area.width + 24;
      _live = at;
      // Quicker the harder it was thrown.
      final ms = (260 - v.dx.abs() / 20).clamp(140, 260).round();
      _run(_Move.tuck, ms);
      return;
    }
    final next = Offset(
      centre.dx < _area.width / 2 ? -1 : 1,
      centre.dy < _area.height / 2 ? -1 : 1,
    );
    if (next != _corner) HapticFeedback.lightImpact();
    _corner = next;
    final to = _restOrigin(band, next);
    final distance = (to - at).distance;
    final along = distance < 1 ? Offset.zero : (to - at) / distance;
    final speed =
        distance < 1 ? 0.0 : (v.dx * along.dx + v.dy * along.dy) / distance;
    _glideTo(at, to, speed);
  }

  void _expand() {
    if (!_settled || _dragging) return;
    _settle.stop();
    _flight.value = 1;
    HapticFeedback.lightImpact();
    _run(_Move.grow, 440);
  }

  void _tuckBySemantics() {
    if (!_settled) return;
    final at = _live ?? _restOrigin(_band(context), _corner);
    _live = at;
    _tuckFrom = at.dx;
    _tuckTo = _corner.dx < 0 ? -_size.width - 24 : _area.width + 24;
    _run(_Move.tuck, 240);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shown) return const SizedBox.shrink();
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) {
          _area = box.biggest;
          final band = _band(context);
          // The band moved under a resting window (the keyboard came up,
          // the window turned): glide with it rather than jump.
          final rest = _restOrigin(band, _corner);
          final last = _lastRest;
          _lastRest = rest;
          if (last != null &&
              (last - rest).distance > 1 &&
              _live == null &&
              !_dragging &&
              _move == _Move.none &&
              !_calm) {
            _live = last;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _live == last) _glideTo(last, rest, 0);
            });
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_flight, _lift, _reshape]),
            builder: (context, _) => Stack(children: [_window(band)]),
          );
        },
      ),
    );
  }

  Widget _window(EdgeInsets band) {
    final size = _size;
    final full = Offset.zero & _area;
    final rest = (_live ?? _restOrigin(band, _corner)) & size;
    final radius = CallPipStage.pipRadiusFor(size);
    final t = _flight.value;
    var rect = rest;
    var r = radius;
    var shadow = 1.0;
    var scale = 1.0;
    var opacity = 1.0;
    switch (_move) {
      case _Move.launch:
        final v = Curves.easeOutBack.transform(t);
        rect = lerpCallRect(_from, rest, v);
        r = radius * v.clamp(0.0, 1.0);
        shadow = v.clamp(0.0, 1.0);
      case _Move.pop:
        scale = 0.5 + 0.5 * Curves.easeOutBack.transform(t);
        opacity = Curves.easeOut.transform((t * 2).clamp(0.0, 1.0));
      case _Move.grow:
        final v = Curves.easeOutCubic.transform(t);
        rect = lerpCallRect(rest, full, v);
        r = radius * (1 - v);
        shadow = 1 - v;
      case _Move.held:
        rect = full;
        r = 0;
        shadow = 0;
      case _Move.handoff:
        rect = full;
        r = 0;
        shadow = 0;
        opacity = 1 - Curves.easeOut.transform(t);
      case _Move.out:
        scale = 1 - 0.4 * Curves.easeInCubic.transform(t);
        opacity = 1 - Curves.easeIn.transform(t);
      case _Move.tuck:
        final v = Curves.easeInCubic.transform(t);
        rect = Rect.fromLTWH(
          _tuckFrom + (_tuckTo - _tuckFrom) * v,
          rest.top,
          size.width,
          size.height,
        );
      case _Move.none:
        break;
    }
    final lift = _lift.value;
    final resting = _settled || _move == _Move.tuck;
    Widget body = CallTileFrame(
      radius: r,
      shadow: shadow,
      lift: lift,
      child: _picture(rect.size),
    );
    final s = scale * (1 + 0.05 * lift);
    if (s != 1) body = Transform.scale(scale: s, child: body);
    if (opacity < 1) {
      body = Opacity(opacity: opacity.clamp(0.0, 1.0), child: body);
    }
    final l10n = AppLocalizations.of(context);
    body = Semantics(
      onDismiss: resting ? _tuckBySemantics : null,
      child: FocusableTap(
        onTap: resting ? _expand : null,
        semanticLabel: l10n.inCallPillReturn,
        shape: FocusRingShape.rounded,
        radius: r,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: resting ? _expand : null,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: body,
        ),
      ),
    );
    // A pan claims before the screens' own drags under it would.
    final mq = MediaQuery.of(context);
    final slop = mq.gestureSettings.touchSlop ?? kTouchSlop;
    body = MediaQuery(
      data: mq.copyWith(
        gestureSettings: DeviceGestureSettings(touchSlop: slop / 3),
      ),
      child: body,
    );
    // Mid-handoff the screen under it is live: let touches through.
    if (_move == _Move.held || _move == _Move.handoff || _move == _Move.out) {
      body = IgnorePointer(child: body);
    }
    return Positioned.fromRect(rect: rect, child: body);
  }

  /// The picture: the call's video, fitted the way the call screen fits
  /// it at full size and filling the window at rest, or a name card.
  Widget _picture(Size box) {
    final spec = _float.spec ?? _lastSpec;
    final r = _float.renderer;
    final video = _float.videoSize;
    final Widget? content;
    final picture = spec != null && !spec.videoOff && spec.trackId != null;
    if (r != null && video != null && picture) {
      final fit = spec.screen ? BoxFit.contain : callFeedFit(video, box);
      content = RTCVideoView(
        r,
        objectFit: fit == BoxFit.contain
            ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
            : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else if (picture) {
      // Between binding and the first frame: the dark ground, never a
      // name card flashing up for a few frames.
      content = null;
    } else {
      content = CallPipNameCard(title: spec?.title ?? '');
    }
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: const Color(0xFF0E0F12),
        child: content == null ? null : RepaintBoundary(child: content),
      ),
    );
  }
}
