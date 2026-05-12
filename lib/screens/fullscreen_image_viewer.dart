import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../widgets/remote_image.dart';

/// Tap-to-zoom fullscreen viewer for a single image stored in Convex.
/// Pinch + double-tap to zoom; swipe-down or X to dismiss.
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.storageId,
    required this.api,
    this.heroTag,
  });

  final String storageId;
  final ChatApi api;
  final Object? heroTag;

  static Future<void> open(
    BuildContext context, {
    required String storageId,
    required ChatApi api,
    Object? heroTag,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => FullscreenImageViewer(
          storageId: storageId,
          api: api,
          heroTag: heroTag,
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
    with SingleTickerProviderStateMixin {
  final TransformationController _xform = TransformationController();
  late final AnimationController _animCtrl;
  Animation<Matrix4>? _animTween;
  double _dragDy = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final t = _animTween;
        if (t != null) _xform.value = t.value;
      });
  }

  @override
  void dispose() {
    _xform.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails d) {
    final isZoomed = _xform.value.getMaxScaleOnAxis() > 1.05;
    Matrix4 target;
    if (isZoomed) {
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
    _animTween = Matrix4Tween(begin: _xform.value, end: target).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl
      ..value = 0
      ..forward();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    // Only allow swipe-to-dismiss when not zoomed.
    if (_xform.value.getMaxScaleOnAxis() > 1.05) return;
    setState(() => _dragDy += d.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    if (_dragDy.abs() > 120) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _dragDy = 0);
  }

  @override
  Widget build(BuildContext context) {
    final dismissFrac = (_dragDy.abs() / 400).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1 - dismissFrac * 0.4),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: _handleDoubleTap,
            onDoubleTap: () {},
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Center(
              child: Transform.translate(
                offset: Offset(0, _dragDy),
                child: Hero(
                  tag: widget.heroTag ?? 'image-${widget.storageId}',
                  child: InteractiveViewer(
                    transformationController: _xform,
                    minScale: 1,
                    maxScale: 5,
                    child: RemoteImage(
                      storageId: widget.storageId,
                      api: widget.api,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
