import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../media/file_url_cache.dart';
import '../media/native_video_player.dart';
import '../media/video_file_cache.dart';
import '../privacy/capture_protection.dart';
import '../theme/theme_scope.dart';
import '../widgets/remote_image.dart';
import '../widgets/video_message.dart' show VideoPlayerSurface;

/// Fullscreen player for a single video stored in Convex — the route a tap on
/// a chat video message opens, mirroring [FullscreenImageViewer] for photos.
///
/// Its first move is to get out of the way: it resolves the storage URL and
/// hands it to the OS player (see [NativeVideoPlayer]), then pops itself. What
/// remains here is the fallback for every case that handoff can't serve — web,
/// a platform that declined, a URL that wouldn't resolve — plus the poster
/// backdrop that covers the resolve so a tap has something to land on rather
/// than a frozen transcript.
///
/// On the fallback path: no pinch-zoom (a video has no reason to support one)
/// and no Hero flight — a `VideoPlayer` texture cannot be flown between routes,
/// see the same note on `MediaPagerScreen`'s active page, which discovered that
/// the hard way. Swipe down or tap the X to dismiss, the same gesture
/// vocabulary [FullscreenImageViewer] uses.
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

  /// Ceiling on the URL resolve before the handoff gives up and lets the
  /// Flutter player take over (which applies its own, longer one). Short
  /// because everything this covers is a single cached Convex lookup, and a
  /// tap that sits on a spinner for ten seconds has already failed the user
  /// whatever eventually comes back.
  static const _resolveTimeout = Duration(seconds: 8);

  /// Download progress, 0…1, or null while there is no figure to show (the
  /// URL resolve, or a response that declared no length). A notifier so the
  /// ring repaints on every chunk without rebuilding the route.
  final ValueNotifier<double?> _progress = ValueNotifier(null);

  bool _dismissing = false;

  /// True once the OS player is off the table and this route has to play the
  /// video itself.
  bool _fallback = false;

  @override
  void initState() {
    super.initState();
    // Both conditions are facts already known here, so they are settled as
    // initial state rather than behind the async handoff. Routed through
    // `_handoff` they would still be correct, but the route would mount
    // showing a handoff plate for a handoff that was never going to happen —
    // a spinner for one frame in front of a player that could have been
    // rendering already.
    _fallback = !NativeVideoPlayer.supported || _shieldNeedsFlutterPlayer;
    if (!_fallback) _handoff();
  }

  /// Android can hand the OS player FLAG_SECURE and be done. iOS has no such
  /// flag — capture protection there is the Flutter-side CaptureShield overlay,
  /// which cannot cover a UIKit view controller presented above the engine. So
  /// while any protection scope is open (an ephemeral room, the user's global
  /// toggle), iOS keeps the video inside Flutter where the shield still reaches
  /// it. Losing the system controls is the cheaper half of that trade.
  bool get _shieldNeedsFlutterPlayer =>
      CaptureProtection.instance.active && !kIsWeb && Platform.isIOS;

  @override
  void dispose() {
    _dragDy.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Resolve, hand to the OS player, and step aside. Any failure along the
  /// way lands on [_fallback] rather than an error state — the Flutter surface
  /// below re-resolves (off the same caches) and draws the real diagnosis,
  /// including the retry and the "this file is gone" case.
  Future<void> _handoff() async {
    final secure = CaptureProtection.instance.active;
    final source = await _source();
    if (!mounted) return;

    if (source != null &&
        await NativeVideoPlayer.present(url: source, secure: secure)) {
      // The OS player owns the screen now, and it outlives this route — so
      // closing it returns to the transcript directly instead of to a poster
      // nobody asked for a second look at.
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (!mounted) return;
    setState(() => _fallback = true);
  }

  /// What to hand the OS player: a `file://` URL for a local copy, the remote
  /// URL when there can't be one, or null when neither is reachable.
  ///
  /// Local wins whenever it is available, and that is the whole point of this
  /// method. Nothing sits in front of `AVPlayer`/`ExoPlayer` caching an HTTP
  /// response, so a streamed video re-downloads in full on every play and
  /// rebuffers on every seek. A cached file starts on the first frame and
  /// scrubs instantly, this time and every time after.
  Future<String?> _source() async {
    Future<String?> remote() => FileUrlCache.instance
        .resolve(widget.storageId, () => widget.api.getFileUrl(widget.storageId))
        .timeout(_resolveTimeout);

    if (!kIsWeb) {
      // Separate from the download below so a hit costs no HTTP client, no
      // progress plumbing, and — because `lookup` never reaches the network —
      // no URL resolve either.
      final hit = await VideoFileCache.instance.lookup(widget.storageId);
      if (hit != null) return Uri.file(hit).toString();

      // A download deliberately outlives a dismissal: backing out mid-fetch
      // and tapping again is the most common thing anyone does here, and
      // abandoning the bytes would make the second tap start over. The size
      // ceiling and the concurrency cap are what keep that bounded.
      try {
        final path = await VideoFileCache.instance.resolve(
          widget.storageId,
          remote,
          onProgress: (received, total) {
            if (!mounted || total == null || total <= 0) return;
            _progress.value = (received / total).clamp(0.0, 1.0);
          },
        );
        return Uri.file(path).toString();
      } on MediaTooLarge {
        // By design: too big to keep, so stream it exactly as before. Not a
        // failure and not worth a log line.
      } catch (e) {
        // A download that failed still leaves streaming as a real option —
        // a truncated write, a full disk, a sandbox that purged the directory
        // mid-fetch. None of those say anything about the network.
        debugPrint('VideoFileCache miss fell through to streaming: $e');
      }
      if (!mounted) return null;
      _progress.value = null;
    }

    try {
      return await remote();
    } catch (e) {
      debugPrint('FullscreenVideoViewer could not resolve a URL: $e');
      return null;
    }
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
            child: _fallback
                ? VideoPlayerSurface(
                    api: widget.api,
                    storageId: widget.storageId,
                    posterStorageId: widget.posterStorageId,
                  )
                : _HandoffPlate(
                    api: widget.api,
                    posterStorageId: widget.posterStorageId,
                    progress: _progress,
                  ),
          ),
        ),
      ),
    );
  }
}

/// What the tap lands on between opening this route and the OS player covering
/// it: the poster full-bleed and dimmed, with a progress ring over it.
/// Deliberately identical in geometry to [VideoPlayerSurface]'s own loading
/// state, so a handoff that falls back doesn't visibly change its mind — and
/// full-bleed for the reason spelled out there, that a poster boxed at a
/// guessed ratio is a stamp floating in the middle of a black screen.
class _HandoffPlate extends StatelessWidget {
  const _HandoffPlate({
    required this.api,
    required this.posterStorageId,
    required this.progress,
  });

  final ChatApi api;
  final String? posterStorageId;

  /// 0…1 once the download reports a total, null before that. A determinate
  /// ring rather than an endless one wherever the figure exists: this wait is
  /// a download of a known size, and saying so is the difference between "it's
  /// working" and "it's stuck".
  final ValueListenable<double?> progress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final poster = posterStorageId;
    return Stack(
      fit: StackFit.expand,
      children: [
        poster == null
            ? const ColoredBox(color: Colors.black)
            : ColoredBox(
                color: Colors.black,
                child: RemoteImage(
                  storageId: poster,
                  api: api,
                  fit: BoxFit.contain,
                ),
              ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
        // Centred inside the expanded child, not laid out as one: under
        // `StackFit.expand` a bare SizedBox gets tight stack-sized
        // constraints and the ring inflates to fill the screen.
        Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 2.5,
                color: theme.accent,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
