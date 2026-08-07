import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../widgets/video_message.dart' show VideoPlayerSurface;

/// Fullscreen player for a single video stored in Convex — the route a tap on
/// a chat video message opens, mirroring [FullscreenImageViewer] for photos.
///
/// No pinch-zoom (a video has no reason to support one) and no Hero flight: a
/// `VideoPlayer` texture cannot be flown between routes — see the same note on
/// `MediaPagerScreen`'s active page, which discovered that the hard way.
/// Swipe down or tap the X to dismiss, the same gesture vocabulary
/// [FullscreenImageViewer] uses.
class FullscreenVideoViewer extends StatefulWidget {
  const FullscreenVideoViewer({
    super.key,
    required this.storageId,
    required this.api,
    this.posterStorageId,
  });

  final String storageId;
  final ChatApi api;

  /// The still frame captured on send, shown as an instant backdrop while the
  /// real video resolves and initializes. Null renders black instead.
  final String? posterStorageId;

  static Future<void> open(
    BuildContext context, {
    required String storageId,
    required ChatApi api,
    String? posterStorageId,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        // Matches FullscreenImageViewer: a direct response to a tap on the
        // thing that opened it, not an animation playing for its own sake.
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, _, _) => FullscreenVideoViewer(
          storageId: storageId,
          api: api,
          posterStorageId: posterStorageId,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<FullscreenVideoViewer> createState() => _FullscreenVideoViewerState();
}

class _FullscreenVideoViewerState extends State<FullscreenVideoViewer> {
  /// Fraction of screen height that commits a drag to a dismiss. Same figure
  /// as [FullscreenImageViewer] — one gesture vocabulary across the app's
  /// fullscreen overlays rather than a subtly different feel per media type.
  static const _dismissFraction = 0.18;

  /// A flick faster than this dismisses regardless of distance.
  static const _dismissVelocity = 700.0;

  /// Live drag offset. A notifier rather than `setState` so a drag repaints
  /// the barrier and chrome without rebuilding the video subtree every frame.
  final ValueNotifier<double> _dragDy = ValueNotifier(0);

  bool _dismissing = false;

  @override
  void dispose() {
    _dragDy.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    _dragDy.value += d.delta.dy;
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final dy = _dragDy.value;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final threshold = MediaQuery.sizeOf(context).height * _dismissFraction;
    // Velocity has to agree with the direction of travel, or a fast upward
    // correction at the end of a downward drag would read as a dismiss.
    final flung = velocity.abs() > _dismissVelocity && velocity.sign == dy.sign;
    if (dy != 0 && (flung || dy.abs() > threshold)) {
      _dismissing = true;
      Navigator.of(context).maybePop();
      return;
    }
    _dragDy.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<double>(
        valueListenable: _dragDy,
        builder: (context, dy, child) {
          final t = (dy.abs() / (screen.height * 0.65)).clamp(0.0, 1.0);
          return Stack(
            children: [
              // Barrier inside the route so it can fade to fully transparent
              // as the drag commits, reading as the video leaving rather than
              // the page cutting away.
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Colors.black.withValues(alpha: 1 - t)),
                ),
              ),
              Transform.translate(offset: Offset(0, dy), child: child),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                right: 8,
                child: Opacity(
                  // The chrome gets out of the way as the video leaves.
                  opacity: (1 - t * 2).clamp(0.0, 1.0),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          );
        },
        // Built once and passed through the builder: the player is the
        // expensive part and none of it depends on the drag offset.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Center(
            child: VideoPlayerSurface(
              api: widget.api,
              storageId: widget.storageId,
              posterStorageId: widget.posterStorageId,
            ),
          ),
        ),
      ),
    );
  }
}
