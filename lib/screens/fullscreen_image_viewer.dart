import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../widgets/remote_image.dart';

/// Fullscreen viewer for a single image stored in Convex.
///
/// Pinch and double-tap to zoom; swipe in any vertical direction or tap the X
/// to dismiss. When the caller supplies a [heroTag] matching a [Hero] around the
/// thumbnail it was opened from, the picture flies between the two.
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.storageId,
    required this.api,
    this.heroTag,
    this.heroRadius,
    this.thumbnailDecodeWidth,
  });

  final String storageId;
  final ChatApi api;

  /// Tag of the [Hero] wrapping the source thumbnail.
  ///
  /// Null means no flight — and null is honoured literally. The previous
  /// implementation substituted `'image-$storageId'` when this was omitted,
  /// which could never match any caller's tag, so every "no tag" open mounted a
  /// lone Hero that quietly did nothing.
  final Object? heroTag;

  /// Corner radius of the source thumbnail, un-rounded to zero across the
  /// flight. Pass `BorderRadius.circular(size)` for a circular avatar so it
  /// squares off on the way out and re-rounds on the way back, instead of
  /// snapping between shapes at the endpoints.
  final BorderRadius? heroRadius;

  /// Decode width in device pixels of the thumbnail this was opened from, used
  /// as the arrival backdrop. See [RemoteImage.placeholderDecodeWidth] — without
  /// it the flight lands on a shimmer even though the bytes are already local.
  final int? thumbnailDecodeWidth;

  static Future<void> open(
    BuildContext context, {
    required String storageId,
    required ChatApi api,
    Object? heroTag,
    BorderRadius? heroRadius,
    int? thumbnailDecodeWidth,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        // Transparent: the barrier is painted inside, so it can fade with the
        // dismiss drag and leave the page underneath visible while the Hero
        // flies home. A solid barrierColor here would black out the return.
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => FullscreenImageViewer(
          storageId: storageId,
          api: api,
          heroTag: heroTag,
          heroRadius: heroRadius,
          thumbnailDecodeWidth: thumbnailDecodeWidth,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer>
    with TickerProviderStateMixin {
  /// Fraction of screen height that commits a slow drag to a dismiss.
  static const _dismissFraction = 0.18;

  /// A flick faster than this dismisses regardless of distance — the gesture
  /// people actually make is a short fast flick, not a long slow drag.
  static const _dismissVelocity = 700.0;

  /// How far the image shrinks at a full-screen drag. Subtle on purpose: enough
  /// to read as "peeling away", not so much that it detaches from the finger.
  static const _dragShrink = 0.28;

  final TransformationController _xform = TransformationController();
  late final AnimationController _zoomCtrl;
  Animation<Matrix4>? _zoomTween;

  /// Live drag offset. A notifier rather than `setState` so a drag repaints one
  /// transform instead of rebuilding the whole route every frame.
  final ValueNotifier<Offset> _drag = ValueNotifier(Offset.zero);

  /// Drives the spring back when a drag is released without committing.
  late final AnimationController _settleCtrl;
  Animation<Offset>? _settleTween;

  bool _dismissing = false;

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
        if (t != null) _drag.value = t.value;
      });
  }

  @override
  void dispose() {
    _xform.dispose();
    _zoomCtrl.dispose();
    _settleCtrl.dispose();
    _drag.dispose();
    super.dispose();
  }

  bool get _zoomed => _xform.value.getMaxScaleOnAxis() > 1.05;

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

  void _onDragStart(DragStartDetails _) {
    _settleCtrl.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // While zoomed the same gesture is panning the image, so dismissal has to
    // stay out of the way.
    if (_zoomed || _dismissing) return;
    _drag.value += Offset(0, d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final dy = _drag.value.dy;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final threshold = MediaQuery.sizeOf(context).height * _dismissFraction;

    // Velocity has to agree with the direction of travel, or a fast *upward*
    // correction at the end of a downward drag would read as a dismiss.
    final flung = velocity.abs() > _dismissVelocity && velocity.sign == dy.sign;
    if (dy != 0 && (flung || dy.abs() > threshold)) {
      _dismissing = true;
      Navigator.of(context).maybePop();
      return;
    }
    _settleTween = Tween(begin: _drag.value, end: Offset.zero).animate(
      CurvedAnimation(parent: _settleCtrl, curve: Curves.easeOutCubic),
    );
    _settleCtrl
      ..value = 0
      ..forward();
  }

  /// 0 while at rest, 1 at a full screen-height drag.
  double _progress(Offset drag, Size screen) =>
      (drag.dy.abs() / (screen.height * 0.65)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final image = RemoteImage(
      storageId: widget.storageId,
      api: widget.api,
      fit: BoxFit.contain,
      borderRadius: BorderRadius.zero,
      placeholderDecodeWidth: widget.thumbnailDecodeWidth,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<Offset>(
        valueListenable: _drag,
        builder: (context, drag, child) {
          final t = _progress(drag, screen);
          return Stack(
            children: [
              // Barrier inside the route so it can fade to fully transparent as
              // the drag commits — that's what makes the Hero return read as the
              // picture going back where it came from rather than a cut.
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 1 - t),
                  ),
                ),
              ),
              Transform.translate(
                offset: drag,
                child: Transform.scale(
                  scale: 1 - t * _dragShrink,
                  child: child,
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                right: 8,
                child: Opacity(
                  // The chrome gets out of the way as the picture leaves.
                  opacity: (1 - t * 2).clamp(0.0, 1.0),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          );
        },
        // Built once and passed through the builder: the image subtree is the
        // expensive part and none of it depends on the drag offset.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: _handleDoubleTap,
          onDoubleTap: () {},
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Center(
            child: InteractiveViewer(
              transformationController: _xform,
              minScale: 1,
              maxScale: 5,
              // Hero wraps the image only, NOT the InteractiveViewer. Wrapping
              // the viewer meant the flight scaled the interactive layer itself,
              // so its gesture geometry was mid-animation garbage for the
              // duration of every open and close.
              child: _maybeHero(image),
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeHero(Widget image) {
    final tag = widget.heroTag;
    if (tag == null) return image;
    final from = widget.heroRadius;
    return Hero(
      tag: tag,
      flightShuttleBuilder: from == null
          ? null
          : (_, animation, direction, _, _) {
              // Un-round the source shape across the flight. Without this an
              // avatar snaps from circle to rectangle at whichever endpoint the
              // shuttle happens to render, which is the single most obvious
              // tell that a flight is a cut and not a movement.
              final tween = BorderRadiusTween(begin: from, end: BorderRadius.zero);
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              );
              return AnimatedBuilder(
                animation: curved,
                builder: (_, _) => ClipRRect(
                  clipBehavior: Clip.antiAlias,
                  borderRadius: tween.evaluate(curved) ?? BorderRadius.zero,
                  child: image,
                ),
              );
            },
      child: image,
    );
  }
}

/// Decode width in device pixels for a thumbnail of [logicalWidth], for passing
/// as [FullscreenImageViewer.thumbnailDecodeWidth].
///
/// Has to agree with what [RemoteImage] actually decoded at, or the viewer's
/// backdrop is a different `ImageCache` entry and misses.
int thumbnailDecodeWidth(BuildContext context, double logicalWidth) =>
    math.max(1, (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round());
