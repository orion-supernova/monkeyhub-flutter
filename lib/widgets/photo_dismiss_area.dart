import 'package:flutter/widgets.dart';

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
  }

  @override
  void dispose() {
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
    final now = _zoomed || _pointers >= 2;
    if (now == _held) return;
    _held = now;
    widget.onZoomChanged?.call(now);
  }

  void _onPointerDown(PointerDownEvent _) {
    _pointers++;
    _report();
  }

  void _onPointerGone(PointerEvent _) {
    if (_pointers > 0) _pointers--;
    _report();
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

  void _handleDoubleTap(TapDownDetails d) {
    if (widget.maxScale <= 1) return;
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
    _pan = d.pointerCount == 1 && !_zoomed ? _Pan.undecided : _Pan.picture;
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
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerGone,
      onPointerCancel: _onPointerGone,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
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
  }
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
