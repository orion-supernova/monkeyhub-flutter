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

  /// Fires when the picture crosses in or out of a zoomed state. The pager
  /// uses it to stop the `PageView` from stealing a pan: while zoomed a
  /// sideways drag is the reader moving around inside one photograph, not
  /// reaching for the next.
  final void Function(bool zoomed)? onZoomChanged;

  final double maxScale;

  @override
  State<PhotoDismissArea> createState() => _PhotoDismissAreaState();
}

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

  bool _dismissing = false;
  bool _wasZoomed = false;

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
    // A pinch changes the matrix without going through `_handleDoubleTap`, so
    // the zoom report has to come off the controller itself rather than off
    // the gesture that happened to cause it.
    _xform.addListener(_reportZoom);
  }

  @override
  void dispose() {
    _xform.removeListener(_reportZoom);
    _xform.dispose();
    _zoomCtrl.dispose();
    _settleCtrl.dispose();
    super.dispose();
  }

  bool get _zoomed => _xform.value.getMaxScaleOnAxis() > 1.05;

  void _reportZoom() {
    final now = _zoomed;
    if (now == _wasZoomed) return;
    _wasZoomed = now;
    widget.onZoomChanged?.call(now);
  }

  void _handleDoubleTap(TapDownDetails d) {
    Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      // Zoom 2.5× centered on the double-tap point.
      const scale = 2.5;
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

  void _onDragStart(DragStartDetails _) => _settleCtrl.stop();

  void _onDragUpdate(DragUpdateDetails d) {
    // While zoomed the same gesture is panning the image, so dismissal has to
    // stay out of the way.
    if (_zoomed || _dismissing) return;
    widget.drag.value += Offset(0, d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
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
    _settleTween = Tween(begin: widget.drag.value, end: Offset.zero).animate(
      CurvedAnimation(parent: _settleCtrl, curve: Curves.easeOutCubic),
    );
    _settleCtrl
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {},
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Center(
        child: InteractiveViewer(
          transformationController: _xform,
          minScale: 1,
          maxScale: widget.maxScale,
          child: widget.child,
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
