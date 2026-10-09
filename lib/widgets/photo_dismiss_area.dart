import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, SystemMouseCursors;
import 'package:flutter/widgets.dart';

import '../platform.dart';

/// The gesture layer under every fullscreen picture: pinch and double-tap to
/// zoom, drag in either vertical direction to dismiss.
///
/// Lifted out of `FullscreenImageViewer`, which had all of this and was the
/// only screen with it — so the swipeable gallery beside it could only be
/// closed by aiming at a 38pt X in the corner, and the two ways of looking at
/// the same photograph disagreed about what a downward flick meant. That is the
/// kind of difference nobody reports and everybody feels.
///
/// The drag OFFSET is written to a notifier the caller owns rather than
/// applied here, because the caller is the only one that knows what should move
/// with it — the barrier fades, the chrome gets out of the way, and in the
/// pager's case a whole `PageView` translates. A notifier rather than a
/// callback with `setState` so a drag repaints one transform per frame instead
/// of rebuilding the route.
class PhotoDismissArea extends StatefulWidget {
  const PhotoDismissArea({
    super.key,
    required this.child,
    required this.drag,
    required this.onDismiss,
    this.onTap,
    this.onZoomChanged,
    this.maxScale = 5,
    this.zoom,
    this.onBackdropClick,
    this.onWheelStep,
    this.pixelSize,
    this.cursorHidden = false,
  });

  /// The picture. Mounted inside the [InteractiveViewer], so it is what zooms.
  final Widget child;

  /// Live drag offset, written here and painted by the caller. Reset to zero
  /// on a released drag that did not commit.
  final ValueNotifier<Offset> drag;

  /// Called once, when a drag commits. Popping is the caller's business: the
  /// pager pops the index it settled on, and a plain viewer pops nothing.
  final VoidCallback onDismiss;

  /// A single tap on the picture. Null means taps are ignored — which is right
  /// for a viewer with no chrome to toggle, and avoids paying the double-tap
  /// timeout on a screen where nothing waits on it.
  final VoidCallback? onTap;

  /// Fires when the picture starts or stops owning the gesture: zoomed in, or
  /// two fingers down. The pager uses it to stop the `PageView` from stealing
  /// a pan or a pinch: while zoomed a sideways drag is the reader moving
  /// around inside one photograph, not reaching for the next. The viewers also
  /// hide their chrome on it, so a zoomed photo has the whole screen.
  final void Function(bool zoomed)? onZoomChanged;

  final double maxScale;

  // ── Desktop and web. None of these do anything on a phone: they answer a
  // mouse, a wheel or a keyboard, which a phone does not have.

  /// Lets a screen's keyboard shortcuts (⌘= ⌘− ⌘0) drive this picture's zoom.
  /// Hand it to the one page that is on screen and null to the rest.
  final PhotoZoomController? zoom;

  /// A mouse click on the black around the picture, Quick Look's "click
  /// outside to close". A click ON the picture does nothing with a mouse:
  /// toggling the chrome on every click made a desktop viewer flicker under
  /// the reader's hand while they were only trying to focus the window.
  /// Touch keeps [onTap] whatever this is.
  final VoidCallback? onBackdropClick;

  /// The plain mouse wheel at fit, or a trackpad's two-finger sideways
  /// swipe: -1 back, 1 on, Telegram Desktop's wheel and Photos' swipe. Null
  /// leaves both doing nothing at fit.
  ///
  /// The swipe has to be caught here. A trackpad's two fingers reach Flutter
  /// as one pan-zoom gesture, and the viewer's scale recognizer (which needs
  /// it for the pinch) wins that arena against the pager's drag every time,
  /// so at fit a sideways swipe used to move nothing at all. Zoomed, the wheel pans instead, and ⌘/Ctrl+wheel
  /// always zooms around the cursor.
  final ValueChanged<int>? onWheelStep;

  /// The picture's size in image pixels, for a double-click's "100%". Asked
  /// once, on the first double-click; null or a null answer falls back to the
  /// phone's 2.5×.
  final Future<Size?> Function()? pixelSize;

  /// Hides the mouse pointer over the picture, with the chrome, after the
  /// reader has stopped moving it. Without this the grab hand of a zoomed
  /// photo would sit in the middle of it forever.
  final bool cursorHidden;

  /// The zoom the picture last came to rest at, for whatever is drawn inside
  /// it — see [PhotoSharpOnZoom]. Rebuilds a dependant only when the zoom has
  /// settled, never on every frame of a pinch.
  static double settledScaleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SettledScale>()
          ?.notifier
          ?.value ??
      1;

  @override
  State<PhotoDismissArea> createState() => _PhotoDismissAreaState();
}

/// What the current one-finger pan is doing, decided on its first move.
enum _Pan { undecided, dismiss, picture }

class _PhotoDismissAreaState extends State<PhotoDismissArea>
    with TickerProviderStateMixin {
  /// Fraction of screen height that commits a slow drag to a dismiss.
  static const _dismissFraction = 0.18;

  /// A flick faster than this dismisses regardless of distance — the gesture
  /// people actually make is a short fast flick, not a long slow drag.
  static const _dismissVelocity = 700.0;

  final TransformationController _xform = TransformationController();
  late final AnimationController _zoomCtrl;
  Animation<Matrix4>? _zoomTween;

  /// Drives the spring back when a drag is released without committing.
  late final AnimationController _settleCtrl;
  Animation<Offset>? _settleTween;

  /// The full-screen box the [InteractiveViewer] zooms, and the picture
  /// centred inside it. Pan limits come from the picture, not the box, so a
  /// zoomed photo stops at its own edges instead of sliding its letterbox
  /// into view.
  final _contentKey = GlobalKey();
  final _pictureKey = GlobalKey();

  bool _dismissing = false;
  bool _held = false;

  /// Whether the last pointer to go down was a mouse on a desktop: a mouse
  /// drag pans a zoomed photo and never starts a dismiss, which on a desk
  /// would be the window throwing the picture away under a click-and-drag.
  bool _mouse = false;

  /// A mouse button is down on a zoomed picture: the grab hand closes.
  bool _grabbing = false;

  /// [_zoomed] as last built, so the grab cursor follows the zoom with a
  /// rebuild only when it actually flips.
  bool _zoomedUi = false;

  final ValueNotifier<double> _settled = ValueNotifier(1);
  Timer? _settleScale;
  Size? _pixels;
  bool _pixelsAsked = false;

  /// The current trackpad gesture may still turn out to be a sideways swipe:
  /// it began at fit and has not scaled.
  bool _swipeArmed = false;

  double _wheelAcc = 0;
  Duration _wheelLast = Duration.zero;
  Duration _wheelLockedUntil = Duration.zero;
  bool _clamping = false;
  int _pointers = 0;
  _Pan _pan = _Pan.undecided;

  @override
  void initState() {
    super.initState();
    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final t = _zoomTween;
        if (t != null) _xform.value = t.value;
      });
    _settleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final t = _settleTween;
        if (t != null) widget.drag.value = t.value;
      });
    // Off the controller rather than off any one gesture: a pinch, a fling's
    // glide and a double-tap's animation all write the matrix, and all of
    // them have to respect the picture's edges and report the zoom.
    _xform
      ..addListener(_clampToPicture)
      ..addListener(_report);
    if (isWebOrDesktop) _xform.addListener(_scheduleSettled);
    widget.zoom?._attach(this);
  }

  @override
  void didUpdateWidget(PhotoDismissArea old) {
    super.didUpdateWidget(old);
    if (!identical(old.zoom, widget.zoom)) {
      old.zoom?._detach(this);
      widget.zoom?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.zoom?._detach(this);
    _settleScale?.cancel();
    _settled.dispose();
    _xform.dispose();
    _zoomCtrl.dispose();
    _settleCtrl.dispose();
    super.dispose();
  }

  bool get _zoomed => _xform.value.getMaxScaleOnAxis() > 1.05;

  /// Zoomed, or two fingers down on the way to being. The pager hears it as
  /// "this page owns the gesture": locking the `PageView` only once the scale
  /// moved let a pinch whose fingers drifted sideways turn into a page swipe.
  void _report() {
    final zoomed = _zoomed;
    if (zoomed != _zoomedUi && isWebOrDesktop && mounted) {
      setState(() => _zoomedUi = zoomed);
    }
    final now = zoomed || _pointers >= 2;
    if (now == _held) return;
    _held = now;
    widget.onZoomChanged?.call(now);
  }

  /// Publishes the zoom once it has been still for a moment. A timer, not
  /// the end of a gesture, because a wheel and a trackpad pinch on the web
  /// have no end: they are a stream of separate events.
  void _scheduleSettled() {
    _settleScale?.cancel();
    _settleScale = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      final s = (_xform.value.getMaxScaleOnAxis() * 100).round() / 100;
      _settled.value = s;
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers++;
    _mouse = isWebOrDesktop && e.kind == PointerDeviceKind.mouse;
    if (_mouse && _zoomed && !_grabbing) setState(() => _grabbing = true);
    _report();
  }

  void _onPointerGone(PointerEvent _) {
    if (_pointers > 0) _pointers--;
    if (_grabbing) setState(() => _grabbing = false);
    _report();
  }

  // ───────────────────────── desktop zoom ─────────────────────────

  /// Scales by [factor] about [focal] (this widget's own coordinates), which
  /// stays put under the cursor: the point you zoom at is the point you see.
  /// Below 1.01× it lands exactly on fit, so a zoom out never leaves the
  /// picture a hair off its letterbox.
  void _zoomAt(Offset focal, double factor, {bool animate = false}) {
    final m = _xform.value;
    final s = m.getMaxScaleOnAxis();
    final target = (s * factor).clamp(1.0, widget.maxScale);
    Matrix4 next;
    if (target < 1.01) {
      next = Matrix4.identity();
    } else {
      final f = target / s;
      if ((f - 1).abs() < 0.0001) return;
      next = Matrix4.identity()
        ..translateByDouble(focal.dx, focal.dy, 0, 1)
        ..scaleByDouble(f, f, 1, 1)
        ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
        ..multiply(m);
    }
    if (animate) {
      _animateTo(next);
    } else {
      _zoomCtrl.stop();
      _xform.value = next;
    }
  }

  void _animateTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(begin: _xform.value, end: target).animate(
      CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeOutCubic),
    );
    _zoomCtrl
      ..value = 0
      ..forward();
  }

  Offset get _centre {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.size.center(Offset.zero)
        : Offset.zero;
  }

  /// The picture's rectangle on screen right now, zoom included.
  Rect? _pictureOnScreen() {
    final content = _contentKey.currentContext?.findRenderObject();
    final picture = _pictureKey.currentContext?.findRenderObject();
    if (content is! RenderBox || picture is! RenderBox) return null;
    if (!content.hasSize || !picture.hasSize || !picture.attached) return null;
    final scene =
        picture.localToGlobal(Offset.zero, ancestor: content) & picture.size;
    return MatrixUtils.transformRect(_xform.value, scene);
  }

  void _onPanZoomStart(PointerPanZoomStartEvent e) {
    _swipeArmed = !_zoomed && widget.onWheelStep != null;
  }

  /// Steps once per swipe, as soon as it is plainly sideways and plainly not
  /// a pinch. Photos moves on the same gesture; the picture does not follow
  /// the fingers here, it slides when the swipe has said where it is going.
  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    if (!_swipeArmed) return;
    if ((e.scale - 1).abs() > 0.05 || _zoomed) {
      _swipeArmed = false;
      return;
    }
    final p = e.pan;
    if (p.dx.abs() < 60 || p.dx.abs() < p.dy.abs() * 2) return;
    _swipeArmed = false;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    // Fingers moving left pull the next picture in, as a swipe does.
    final dir = p.dx < 0 ? 1 : -1;
    widget.onWheelStep?.call(rtl ? -dir : dir);
  }

  void _onSignal(PointerSignalEvent e) {
    if (!isWebOrDesktop || e is! PointerScrollEvent) return;
    // Claimed, so the pager behind does not scroll a fraction of a page on
    // the same event. Registration is first come, and this sits inside it.
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final ev = event as PointerScrollEvent;
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed) {
        // 200 is the factor InteractiveViewer itself uses for a wheel.
        _zoomAt(ev.localPosition, math.exp(-ev.scrollDelta.dy / 200));
        return;
      }
      if (_zoomed) {
        // A trackpad's scroll is already a pan inside the viewer.
        if (ev.kind == PointerDeviceKind.trackpad) return;
        // The wheel pans, Shift turning it sideways, as in Preview.
        final d = keys.isShiftPressed
            ? Offset(ev.scrollDelta.dy, 0)
            : ev.scrollDelta;
        _xform.value = _xform.value.clone()
          ..leftTranslateByDouble(-d.dx, -d.dy, 0, 1);
        return;
      }
      _wheelStep(ev);
    });
  }

  /// One page per deliberate turn of the wheel. A free-spinning wheel and a
  /// trackpad's momentum both send a long tail of events after the reader
  /// has stopped; the lock swallows them, and for a trackpad keeps
  /// swallowing for as long as the tail keeps coming.
  void _wheelStep(PointerScrollEvent e) {
    final step = widget.onWheelStep;
    if (step == null) return;
    final now = e.timeStamp;
    final trackpad = e.kind == PointerDeviceKind.trackpad;
    if (now < _wheelLockedUntil) {
      if (trackpad) _wheelLockedUntil = now + const Duration(milliseconds: 160);
      return;
    }
    if (now - _wheelLast > const Duration(milliseconds: 300)) _wheelAcc = 0;
    _wheelLast = now;
    final d = e.scrollDelta;
    _wheelAcc += d.dy.abs() >= d.dx.abs() ? d.dy : d.dx;
    if (_wheelAcc.abs() < (trackpad ? 40 : 10)) return;
    final dir = _wheelAcc > 0 ? 1 : -1;
    _wheelAcc = 0;
    _wheelLockedUntil = now + const Duration(milliseconds: 220);
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    // Sideways on a trackpad follows the content, like a swipe; RTL flips
    // only that, a wheel's down is "on" in every script.
    step(trackpad && d.dx.abs() > d.dy.abs() && rtl ? -dir : dir);
  }

  /// A click with a mouse: on the black around the picture it closes; on the
  /// picture it does nothing. Touch toggles the chrome, as it always has.
  void _onTapUp(TapUpDetails d) {
    if (isWebOrDesktop && d.kind == PointerDeviceKind.mouse) {
      final click = widget.onBackdropClick;
      if (click == null) return;
      final picture = _pictureOnScreen();
      if (picture != null && !picture.contains(d.localPosition)) click();
      return;
    }
    widget.onTap?.call();
  }

  /// "100%": one image pixel to one screen pixel, which is what a desk
  /// means by actual size. Null when the picture's size is not known.
  double? _actualScale() {
    final px = _pixels;
    final content = _contentKey.currentContext?.findRenderObject();
    final picture = _pictureKey.currentContext?.findRenderObject();
    if (px == null || picture is! RenderBox || !picture.hasSize) return null;
    if (content is! RenderBox || picture.size.width <= 0) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return px.width / dpr / picture.size.width;
  }

  /// Keeps the zoomed picture covering the screen on any axis where it is
  /// larger than the screen, and centred on any axis where it is not.
  void _clampToPicture() {
    if (_clamping) return;
    final content = _contentKey.currentContext?.findRenderObject();
    if (content is! RenderBox || !content.hasSize) return;
    final view = content.size;
    var rect = Offset.zero & view;
    final picture = _pictureKey.currentContext?.findRenderObject();
    if (picture is RenderBox &&
        picture.hasSize &&
        !picture.size.isEmpty &&
        picture.attached) {
      rect = picture.localToGlobal(Offset.zero, ancestor: content) &
          picture.size;
    }
    final m = _xform.value;
    final s = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    double axis(double at, double lo, double extent, double viewExtent) {
      final scaled = extent * s;
      if (scaled <= viewExtent) return (viewExtent - scaled) / 2 - lo * s;
      return at.clamp(viewExtent - (lo + extent) * s, -lo * s);
    }
    final x = axis(t.x, rect.left, rect.width, view.width);
    final y = axis(t.y, rect.top, rect.height, view.height);
    if ((x - t.x).abs() < 0.01 && (y - t.y).abs() < 0.01) return;
    _clamping = true;
    _xform.value = m.clone()..setTranslationRaw(x, y, t.z);
    _clamping = false;
  }

  Future<void> _handleDoubleTap(TapDownDetails d) async {
    if (widget.maxScale <= 1) return;
    if (isWebOrDesktop && d.kind == PointerDeviceKind.mouse) {
      if (_zoomed) {
        _animateTo(Matrix4.identity());
        return;
      }
      final ask = widget.pixelSize;
      if (_pixels == null && ask != null && !_pixelsAsked) {
        _pixelsAsked = true;
        _pixels = await ask();
        if (!mounted) return;
      }
      // Actual size when it is a real zoom; a picture already shown at or
      // near its own size gets the phone's 2.5× rather than a twitch.
      final actual = _actualScale();
      final target = actual != null && actual > 1.25
          ? actual
          : (widget.maxScale < 2.5 ? widget.maxScale : 2.5);
      _zoomAt(d.localPosition, target, animate: true);
      return;
    }
    Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      // Zoom 2.5× centered on the double-tap point. The detector and the
      // viewer now share one full-screen box, so the tap's local position is
      // the viewer's own coordinates.
      final scale = widget.maxScale < 2.5 ? widget.maxScale : 2.5;
      final x = -d.localPosition.dx * (scale - 1);
      final y = -d.localPosition.dy * (scale - 1);
      target = Matrix4.identity()
        ..translateByDouble(x, y, 0.0, 1.0)
        ..scaleByDouble(scale, scale, scale, 1.0);
    }
    _zoomTween = Matrix4Tween(begin: _xform.value, end: target).animate(
      CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeOutCubic),
    );
    _zoomCtrl
      ..value = 0
      ..forward();
  }

  // The dismiss drag rides the viewer's own scale gesture rather than a
  // vertical-drag detector around it. Two recognizers over one picture raced
  // for every touch: a pinch whose first finger moved vertically before the
  // second landed was taken as a dismiss, and the pinch never started.

  void _onInteractionStart(ScaleStartDetails d) {
    _settleCtrl.stop();
    _zoomCtrl.stop();
    _pan = d.pointerCount == 1 && !_zoomed && !_mouse
        ? _Pan.undecided
        : _Pan.picture;
  }

  void _onInteractionUpdate(ScaleUpdateDetails d) {
    if (_dismissing) return;
    if (d.pointerCount > 1 || _zoomed) {
      // A second finger turns a dismiss into a pinch; the picture goes back
      // to where it was rather than pinching somewhere mid-air.
      if (_pan == _Pan.dismiss) _settle();
      _pan = _Pan.picture;
      return;
    }
    final delta = d.focalPointDelta;
    if (_pan == _Pan.undecided) {
      if (delta == Offset.zero) return;
      _pan = delta.dy.abs() >= delta.dx.abs() ? _Pan.dismiss : _Pan.picture;
    }
    if (_pan == _Pan.dismiss) widget.drag.value += Offset(0, delta.dy);
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    final pan = _pan;
    _pan = _Pan.undecided;
    if (_dismissing) return;
    // A finger still down means the gesture changed shape (a second finger
    // landed, or one of two lifted), not that the reader let go.
    if (pan != _Pan.dismiss || d.pointerCount > 0) {
      if (widget.drag.value != Offset.zero) _settle();
      return;
    }
    final dy = widget.drag.value.dy;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final threshold = MediaQuery.sizeOf(context).height * _dismissFraction;

    // Velocity has to agree with the direction of travel, or a fast *upward*
    // correction at the end of a downward drag would read as a dismiss.
    final flung = velocity.abs() > _dismissVelocity && velocity.sign == dy.sign;
    if (dy != 0 && (flung || dy.abs() > threshold)) {
      _dismissing = true;
      widget.onDismiss();
      return;
    }
    _settle();
  }

  void _settle() {
    _settleTween = Tween(begin: widget.drag.value, end: Offset.zero).animate(
      CurvedAnimation(parent: _settleCtrl, curve: Curves.easeOutCubic),
    );
    _settleCtrl
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isWebOrDesktop;
    final Widget area = Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerGone,
      onPointerCancel: _onPointerGone,
      onPointerSignal: desktop ? _onSignal : null,
      onPointerPanZoomStart: desktop ? _onPanZoomStart : null,
      onPointerPanZoomUpdate: desktop ? _onPanZoomUpdate : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // onTapUp rather than onTap for the pointer's kind; it fires at the
        // same moment, after the double-tap window, as onTap did.
        onTapUp: widget.onTap != null ||
                (desktop && widget.onBackdropClick != null)
            ? _onTapUp
            : null,
        onDoubleTapDown: _handleDoubleTap,
        onDoubleTap: () {},
        // The viewer fills the whole area, not just the picture: a pinch
        // starting on the black around a photo zooms it, and a zoomed photo
        // spreads over the screen instead of being cut off at the box it
        // was letterboxed into.
        child: InteractiveViewer(
          transformationController: _xform,
          minScale: 1,
          maxScale: widget.maxScale,
          clipBehavior: Clip.none,
          // The wheel is this widget's (see [_onSignal]): left to the viewer
          // a plain scroll zoomed, which is not what a wheel does over a
          // photograph anywhere else on a desk. Infinity makes the viewer's
          // own wheel zoom a factor of exactly 1. A trackpad pinch (and on
          // the web ⌘+pinch, which arrives as a scale event) still zooms
          // through the viewer, around the fingers.
          scaleFactor: desktop ? double.infinity : 200,
          onInteractionStart: _onInteractionStart,
          onInteractionUpdate: _onInteractionUpdate,
          onInteractionEnd: _onInteractionEnd,
          child: SizedBox.expand(
            key: _contentKey,
            child: Center(
              child: KeyedSubtree(key: _pictureKey, child: widget.child),
            ),
          ),
        ),
      ),
    );
    if (!desktop) return area;
    return _SettledScale(
      notifier: _settled,
      child: MouseRegion(
        cursor: widget.cursorHidden
            ? SystemMouseCursors.none
            : _zoomedUi
                ? (_grabbing
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.grab)
                : MouseCursor.defer,
        child: area,
      ),
    );
  }
}

/// Commands for the picture on screen, from a screen's keyboard shortcuts.
///
/// One per viewer, attached to whichever [PhotoDismissArea] it is handed to;
/// the gallery hands it only to the page being looked at, so ⌘= zooms the
/// photograph you see and not a neighbour built off screen.
class PhotoZoomController {
  _PhotoDismissAreaState? _area;

  void _attach(_PhotoDismissAreaState a) => _area = a;
  void _detach(_PhotoDismissAreaState a) {
    if (identical(_area, a)) _area = null;
  }

  /// Whether a zoomable picture is attached at all (a video's poster is not).
  bool get canZoom => (_area?.widget.maxScale ?? 1) > 1;

  void zoomIn() => _step(1.5);
  void zoomOut() => _step(1 / 1.5);

  /// Back to the whole picture.
  void fit() {
    final a = _area;
    if (a == null || !a._zoomed) return;
    a._animateTo(Matrix4.identity());
  }

  void _step(double factor) {
    final a = _area;
    if (a == null || !canZoom) return;
    a._zoomAt(a._centre, factor, animate: true);
  }
}

/// Draws a sharper decode of the picture over [child] once it has been zoomed
/// past what the screen-sized decode can show.
///
/// The viewer decodes a photograph at the screen's longest edge, which is
/// exactly right at fit and soft at 2×. The file on disk is full resolution
/// (see `RemoteImage`), so sharpening is a second DECODE of bytes already
/// here, not a download: [sharp] builds the same picture at a bigger decode
/// width, quiet while it decodes, and the fit-sized one stays underneath so
/// nothing blinks. Bucketed to 2× and 4× so a pinch that wanders does not
/// decode again for every tenth of a step, and decided only when the zoom
/// has settled ([PhotoDismissArea.settledScaleOf]), never mid-gesture.
///
/// Desktop and web only: a phone's pinch is brief and its memory is not
/// the place to hold a 12 MP bitmap for it.
class PhotoSharpOnZoom extends StatelessWidget {
  const PhotoSharpOnZoom({super.key, required this.child, required this.sharp});

  final Widget child;
  final Widget Function(int decodeWidth) sharp;

  /// A decode this wide is 64 MB at 4:3. Past it the picture is very
  /// unlikely to have the pixels anyway.
  static const int _maxDecode = 8192;

  @override
  Widget build(BuildContext context) {
    if (!isWebOrDesktop) return child;
    final scale = PhotoDismissArea.settledScaleOf(context);
    final bucket = scale <= 2 ? 2 : 4;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screen = MediaQuery.sizeOf(context);
    final base = math.max(screen.width, screen.height) * dpr;
    // One shape whether or not the overlay is up, so zooming in never
    // remounts the picture underneath it.
    return LayoutBuilder(
      builder: (context, box) {
        final want = box.maxWidth.isFinite
            ? math.min(_maxDecode, (box.maxWidth * dpr * bucket).round())
            : 0;
        final sharpen = scale >= 1.25 && want > base * 1.05;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            if (sharpen)
              Positioned.fill(child: IgnorePointer(child: sharp(want))),
          ],
        );
      },
    );
  }
}

class _SettledScale extends InheritedNotifier<ValueNotifier<double>> {
  const _SettledScale({required super.notifier, required super.child});
}

/// How far along a dismiss drag of [drag] is on a screen of [screen]: 0 at
/// rest, 1 at a drag of about two thirds the screen's height.
///
/// Shared so the barrier, the chrome and the picture's own shrink all read the
/// same number. They used to each be given it by the one screen that had a
/// dismiss gesture; now two screens have one.
double photoDismissProgress(Offset drag, Size screen) =>
    (drag.dy.abs() / (screen.height * 0.65)).clamp(0.0, 1.0);

/// How far the picture shrinks at a full-screen drag. Subtle on purpose: enough
/// to read as "peeling away", not so much that it detaches from the finger.
const double kPhotoDismissShrink = 0.28;
