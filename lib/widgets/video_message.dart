import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../backend/chat_api.dart';
import '../media/file_url_cache.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';

/// The chat-bubble tile for a video message: a static poster with a play
/// glyph, never the video itself. Tapping hands off to [onOpen], which
/// `message_bubble.dart` wires to `FullscreenVideoViewer.open` — kept out of
/// this file so a widget three call sites share doesn't have to reach up into
/// `screens/` (which also owns `message_bubble.dart`'s import of
/// `FullscreenImageViewer`, the same layering this mirrors).
///
/// This tile used to *be* a live `VideoPlayerController`: it resolved the
/// storage URL and called `initialize()` — a real network fetch — the instant
/// the bubble scrolled into view, with no timeout on either step. Opening a
/// room with a few video messages therefore fired that many concurrent video
/// pipelines alongside the room's own subscription storm, and a fetch that
/// stalled (an OS-suspend network blip, a mid-reconnect socket) left its
/// bubble spinning forever — indistinguishable from a hang. A poster costs one
/// cached image lookup and no network video I/O at all; the real player, with
/// its own timeout and retry, now exists only once something has actually
/// asked to watch.
class VideoMessage extends StatelessWidget {
  const VideoMessage({
    super.key,
    required this.api,
    required this.storageId,
    required this.isMine,
    this.posterStorageId,
    this.mediaAspectRatio,
    this.durationMs,
    this.maxWidth,
    this.onOpen,
  });

  final ChatApi api;
  final String? storageId;
  final bool isMine;

  /// Still frame captured on send. Null for a video sent from web (no
  /// extractor there) or from before this field existed — the generic film
  /// glyph covers both.
  final String? posterStorageId;

  /// Width÷height of the video, when the sender recorded it. Sizes the tile
  /// at the video's true shape instead of the fallback proportions.
  final double? mediaAspectRatio;

  /// Recorded length, for the corner badge. Null on anything sent before the
  /// field existed.
  final int? durationMs;

  /// Widest the tile may get, normally `ChatMetrics.videoMaxWidth` from the
  /// enclosing chat pane. Null falls back to [ChatMetrics.videoMin], which is
  /// the 280 this used to hard-code — so phones are unchanged.
  final double? maxWidth;

  /// Opens the real player. Null disables the tap — defensive only; every
  /// live call site wires this.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final id = storageId;
    final boxW = maxWidth ?? ChatMetrics.videoMin;

    // Sized at the video's own shape when known. Unknown keeps the exact
    // 240×180-inside-280 proportions this used to hard-code, so a video sent
    // before `mediaAspectRatio` existed looks exactly as it always did.
    final double tileW;
    final double tileH;
    final ratio = mediaAspectRatio;
    if (ratio != null && ratio.isFinite && ratio > 0) {
      tileW = boxW;
      // Floored a hair above the play glyph's 52px footprint rather than at
      // 1px: an extreme-wide ratio (unvalidated sender metadata) would
      // otherwise squash the poster to an invisible sliver while the glyph
      // still forced the surrounding Stack to its own ~52px height anyway —
      // same box, hidden picture.
      tileH = (tileW / ratio).clamp(56.0, boxW * ChatMetrics.videoAspectCap);
    } else {
      tileW = boxW * (240 / 280);
      tileH = boxW * (180 / 280);
    }

    Widget backdrop;
    if (id == null || id.isEmpty) {
      backdrop = Container(
        color: theme.surfaceSunken,
        alignment: Alignment.center,
        child: Icon(Icons.videocam_off_outlined, color: theme.inkMuted),
      );
    } else {
      final poster = posterStorageId;
      backdrop = Stack(
        fit: StackFit.expand,
        children: [
          poster == null
              ? Container(
                  color: theme.surfaceSunken,
                  alignment: Alignment.center,
                  child: Icon(Icons.movie_creation_outlined,
                      size: 28, color: theme.inkMuted),
                )
              : RemoteImage(storageId: poster, api: api, fit: BoxFit.cover),
          // So the white play glyph still reads over a bright poster.
          Container(color: Colors.black.withValues(alpha: 0.18)),
        ],
      );
    }

    return GestureDetector(
      onTap: id == null ? null : onOpen,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: boxW,
              maxHeight: boxW * ChatMetrics.videoAspectCap,
            ),
            child: SizedBox(width: tileW, height: tileH, child: backdrop),
          ),
          if (id != null)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
          if (id != null && durationMs != null)
            Positioned(
              right: 6,
              bottom: 6,
              child: _DurationBadge(durationMs!),
            ),
        ],
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge(this.ms);
  final int ms;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        formatClockDuration(Duration(milliseconds: ms)),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

/// How [VideoPlayerSurface] is currently rendering. Mirrors `AudioMessage`'s
/// `_Phase` split for the same reason: "failed" (worth a retry — a dropped
/// packet, a stalled fetch) and "unavailable" (a burned view-once file, a
/// swept blob — nothing a retry can do about that) are different facts, and a
/// widget that draws the same dead end for both is lying to whichever one it
/// wasn't.
enum _SurfacePhase { loading, ready, failed, unavailable }

/// The real player: resolves the storage URL, initializes a
/// `VideoPlayerController`, and plays — with a hard ceiling on both steps and
/// a tap-to-retry on failure, so a stalled fetch never leaves this stuck
/// spinning the way the old inline tile could.
///
/// Fills whatever box its parent hands it: an [AspectRatio] at the video's
/// true shape once ready, a full-bleed backdrop (the poster, or black) while
/// loading or on error. Used full-bleed by `FullscreenVideoViewer` and by
/// `MediaPagerScreen`'s active page — never inline in the transcript, which
/// only ever shows [VideoMessage]'s static poster.
class VideoPlayerSurface extends StatefulWidget {
  const VideoPlayerSurface({
    super.key,
    required this.api,
    required this.storageId,
    this.posterStorageId,
    this.autoplay = true,
  });

  final ChatApi api;
  final String? storageId;
  final String? posterStorageId;

  /// Starts playback the instant the controller is ready. On, because both
  /// call sites are a direct response to a tap that asked to watch this —
  /// there is no case here where landing on a paused first frame is right.
  final bool autoplay;

  @override
  State<VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends State<VideoPlayerSurface> {
  /// Covers the whole load, not just the network fetch — same fix
  /// `audio_message.dart` already carries for the identical failure mode: a
  /// fetch the platform layer can neither open nor error on just stops, and
  /// without a ceiling that leaves the viewer on its spinner forever. A
  /// failure this ceiling turns that into has a retry on it; a spinner that
  /// never resolves does not.
  static const _loadTimeout = Duration(seconds: 45);

  VideoPlayerController? _controller;
  _SurfacePhase _phase = _SurfacePhase.loading;

  /// Guards a slow resolve landing after a retry — or a `didUpdateWidget` swap
  /// on a recycled row — has already started a newer attempt.
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerSurface old) {
    super.didUpdateWidget(old);
    if (old.storageId == widget.storageId) return;
    _controller?.dispose();
    _controller = null;
    setState(() => _phase = _SurfacePhase.loading);
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.storageId;
    final gen = ++_gen;
    if (id == null || id.isEmpty) {
      setState(() => _phase = _SurfacePhase.unavailable);
      return;
    }
    try {
      final url = await FileUrlCache.instance
          .resolve(id, () => widget.api.getFileUrl(id))
          .timeout(_loadTimeout);
      // The state that started this resolve may already be gone — a pager
      // swipe or a viewer close both tear down synchronously, well before a
      // cold cache miss's round trip settles. Bail before spending a real
      // network video fetch nobody is watching.
      if (!mounted || gen != _gen) return;
      if (url == null) throw const FileUnavailable();

      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await c.initialize().timeout(_loadTimeout);
      } catch (e) {
        // `.timeout()` does not cancel the future underneath it, so a stalled
        // init may still be running against this controller — dispose it
        // without awaiting rather than leaving it orphaned with nobody
        // holding a reference once it (eventually) settles.
        c.dispose();
        rethrow;
      }
      if (!mounted || gen != _gen) {
        c.dispose();
        return;
      }
      if (widget.autoplay) c.play();
      setState(() {
        _controller = c;
        _phase = _SurfacePhase.ready;
      });
    } on FileUnavailable {
      if (!mounted || gen != _gen) return;
      setState(() => _phase = _SurfacePhase.unavailable);
    } catch (e) {
      debugPrint('VideoPlayerSurface: ${widget.storageId} failed to load: $e');
      if (!mounted || gen != _gen) return;
      setState(() => _phase = _SurfacePhase.failed);
    }
  }

  void _retry() {
    final id = widget.storageId;
    if (id == null) return;
    // The likeliest reason a second attempt succeeds where the first didn't
    // is a stale cached URL — `FileUrlCache.invalidate` forces a fresh one.
    FileUrlCache.instance.invalidate(id);
    setState(() => _phase = _SurfacePhase.loading);
    _load();
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  /// The poster, letterboxed on black, or plain black when there is none —
  /// what "loading" and every error state sit on top of.
  Widget _backdrop() {
    final poster = widget.posterStorageId;
    if (poster == null) return const ColoredBox(color: Colors.black);
    return ColoredBox(
      color: Colors.black,
      child: RemoteImage(storageId: poster, api: widget.api, fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    if (_phase == _SurfacePhase.unavailable) {
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          _backdrop(),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          const Icon(Icons.videocam_off_outlined, color: Colors.white, size: 36),
        ],
      );
    }

    if (_phase == _SurfacePhase.failed) {
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          _backdrop(),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          GestureDetector(
            onTap: _retry,
            child: const Icon(Icons.refresh, color: Colors.white, size: 36),
          ),
        ],
      );
    }

    if (_phase == _SurfacePhase.loading) {
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          _backdrop(),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.accent),
          ),
        ],
      );
    }

    final c = _controller!;
    // `VideoPlayerValue.aspectRatio` itself already coerces a zero-size or
    // non-positive ratio to 1.0 — it can never report exactly 0 — so the
    // fallback has to be driven off the raw size to ever actually fire, for
    // the one real case that produces it: an initialized asset the platform
    // never reported dimensions for (a corrupt codec, an audio file sent as
    // MessageType.video).
    final size = c.value.size;
    return AspectRatio(
      aspectRatio:
          size.width == 0 || size.height == 0 ? 16 / 9 : c.value.aspectRatio,
      child: GestureDetector(
        onTap: _toggle,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            if (!c.value.isPlaying)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                colors: VideoProgressColors(
                  playedColor: theme.accent,
                  bufferedColor: Colors.white.withValues(alpha: 0.35),
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
