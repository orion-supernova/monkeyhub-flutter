import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/file_url_cache.dart';
import '../media/video_file_cache.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';

/// How the circular bubble is currently rendering.
///
/// The same four-way split `audio_message.dart` and `video_message.dart` both
/// carry, for the same reason: "failed" is worth a retry and "unavailable" is
/// not, and one dead end drawn for both is a lie to whichever it wasn't.
enum VideoNotePhase { loading, ready, failed, unavailable }

/// What the circle should DRAW, derived from what the player reports.
///
/// A value type produced by a free function, exactly like `AudioDisplay` — and
/// for the same reason. The interesting part of this widget is not the
/// painting, it is this translation, and it has the identical trap in it:
/// `video_player` leaves `isPlaying` true when a clip completes on some
/// platforms and the position stops a tick short of the duration on all of
/// them, so a finished note otherwise draws a pause glyph over a ring that
/// never closes.
@immutable
class VideoNoteDisplay {
  const VideoNoteDisplay({
    required this.playing,
    required this.progress,
    required this.remaining,
  });

  /// Whether to draw the pause glyph, and whether a tap means "pause".
  final bool playing;

  /// 0..1 for the ring around the circle.
  final double progress;

  /// What the readout inside the circle says.
  ///
  /// Counting DOWN, not up. A video note is a fixed, short thing and the
  /// question a reader has is "how much longer", which is also what the badge
  /// says before playback starts — so the number never changes meaning between
  /// the idle state and the playing one.
  final Duration remaining;
}

/// Translates a raw player state into what the circle shows.
///
/// [completed] is the authority when it is set: the note is not playing, the
/// ring is closed, and the readout is back to the full duration ready for a
/// replay. Without that, the first tap after a note ends goes down the "pause"
/// branch and appears to do nothing — the bug `audio_message.dart` documents,
/// which is worth not shipping twice.
VideoNoteDisplay videoNoteDisplayFor({
  required bool rawPlaying,
  required bool completed,
  required Duration position,
  required Duration total,
}) {
  if (completed || total <= Duration.zero) {
    return VideoNoteDisplay(
      playing: false,
      progress: completed ? 1 : 0,
      remaining: total,
    );
  }
  final clamped = position > total ? total : position;
  return VideoNoteDisplay(
    playing: rawPlaying,
    progress: (clamped.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0),
    remaining: total - clamped,
  );
}

/// The playback surface a [VideoNoteMessage] drives.
///
/// An interface, so the bubble's whole state machine — loading, playing,
/// paused, ended, failed — can be exercised with no codec, no network and no
/// platform view. [VideoNotePlayerController] is the real one; tests supply
/// their own. This is the only way any of this is testable: a
/// `VideoPlayerController` cannot be initialized in a widget test.
abstract class VideoNotePlayback implements Listenable {
  /// Opens the source. Throws to signal failure; the bubble turns that into
  /// [VideoNotePhase.failed].
  Future<void> load();

  Duration get position;
  Duration get duration;
  bool get isPlaying;

  /// True once playback has reached the end. Read separately from [isPlaying]
  /// because the two disagree — see [videoNoteDisplayFor].
  bool get isCompleted;

  Future<void> play();
  Future<void> pause();
  Future<void> seekToStart();

  /// The picture. A `VideoPlayer` for the real implementation, anything at all
  /// for a fake.
  Widget view();

  void dispose();
}

/// The real playback, over `video_player`.
class VideoNotePlayerController extends ChangeNotifier
    implements VideoNotePlayback {
  VideoNotePlayerController({required this.source, required this.isFile});

  /// A local path when [isFile], otherwise a URL.
  final String source;
  final bool isFile;

  VideoPlayerController? _controller;

  @override
  Future<void> load() async {
    final c = isFile
        ? VideoPlayerController.file(File(source))
        : VideoPlayerController.networkUrl(Uri.parse(source));
    try {
      await c.initialize();
    } catch (e) {
      // `.timeout()` upstream does not cancel the future underneath it, so a
      // stalled init may still be running — dispose without awaiting rather
      // than orphaning it. Same handling `VideoPlayerSurface` uses.
      unawaited(c.dispose());
      rethrow;
    }
    // Looping is deliberately OFF. A note that restarts itself forever is a
    // moving object in a transcript people are reading past.
    _controller = c;
    c.addListener(notifyListeners);
    notifyListeners();
  }

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  @override
  bool get isCompleted => _controller?.value.isCompleted ?? false;

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> seekToStart() async => _controller?.seekTo(Duration.zero);

  @override
  Widget view() {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    final size = c.value.size;
    // Cover, via a FittedBox around the video's own natural size: the recorded
    // frame is 4∶3 and the bubble is a circle, so anything else letterboxes a
    // rectangle inside a round hole. This is the same crop the composer's live
    // preview applies, which is what makes the sent note match what the sender
    // framed.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width == 0 ? 1 : size.width,
        height: size.height == 0 ? 1 : size.height,
        child: VideoPlayer(c),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(notifyListeners);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}

/// A video note: a circular bubble that plays in place.
///
/// Deliberately NOT the fullscreen video path. A note is a glance — a few
/// seconds of somebody's face — and pushing a full-screen player for it would
/// be three route transitions to watch four seconds of video. It plays where it
/// sits, pauses on a second tap, and shows its own remaining time in the middle
/// of the circle with a progress ring around the edge.
///
/// The bubble has no surrounding chat bubble for the same reason a photo has
/// none: alignment in the parent row already says whose it is, and a frame
/// around a round picture is noise.
class VideoNoteMessage extends StatefulWidget {
  const VideoNoteMessage({
    super.key,
    required this.api,
    required this.storageId,
    required this.isMine,
    this.posterStorageId,
    this.durationMs,
    this.diameter = 180,
    this.playbackFactory,
    this.resolveSource,
  });

  final ChatApi api;
  final String? storageId;
  final bool isMine;

  /// Still frame captured on send, drawn under the circle before anything is
  /// loaded so the bubble has a face in it rather than a grey disc.
  final String? posterStorageId;

  /// Recorded length, so the readout is right before the player exists.
  final int? durationMs;

  final double diameter;

  /// Builds the playback. Null uses `video_player`; tests pass a fake.
  @visibleForTesting
  final VideoNotePlayback Function(String source, bool isFile)? playbackFactory;

  /// Turns a storage id into a playable source: `(source, isFile)`, or null
  /// when the backend has nothing.
  ///
  /// A second seam beside [playbackFactory], not folded into it, because the
  /// two failures they stand in for are different and both need testing: a
  /// source that cannot be resolved is [VideoNotePhase.unavailable] and offers
  /// no retry, while a source that resolves and then will not open is
  /// [VideoNotePhase.failed] and does. Null uses the real caches.
  @visibleForTesting
  final Future<(String, bool)?> Function(String storageId)? resolveSource;

  @override
  State<VideoNoteMessage> createState() => _VideoNoteMessageState();
}

class _VideoNoteMessageState extends State<VideoNoteMessage> {
  /// Covers the whole load, not just the fetch — the ceiling
  /// `audio_message.dart` and `VideoPlayerSurface` both carry, for the failure
  /// where a source the platform can neither open nor error on simply stops.
  static const _loadTimeout = Duration(seconds: 45);

  VideoNotePlayback? _playback;
  VideoNotePhase _phase = VideoNotePhase.loading;

  /// Nothing is loaded until someone asks. A transcript with ten notes in it
  /// must not open ten video pipelines as it scrolls — the exact regression
  /// `video_message.dart`'s header documents having already been fixed once.
  bool _requested = false;

  /// Guards a slow resolve landing after a recycled row has moved on.
  int _gen = 0;

  @override
  void didUpdateWidget(covariant VideoNoteMessage old) {
    super.didUpdateWidget(old);
    if (old.storageId == widget.storageId) return;
    // `message_bubble.dart` builds this with no key, so the ListView recycles
    // one State onto a different message. Without this the circle keeps playing
    // — and counting down — the previous note.
    _gen++;
    _disposePlayback();
    setState(() {
      _phase = VideoNotePhase.loading;
      _requested = false;
    });
  }

  @override
  void dispose() {
    _disposePlayback();
    super.dispose();
  }

  void _disposePlayback() {
    final p = _playback;
    _playback = null;
    p?.removeListener(_onTick);
    p?.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final id = widget.storageId;
    if (id == null || id.isEmpty) {
      setState(() => _phase = VideoNotePhase.unavailable);
      return;
    }
    final gen = ++_gen;
    setState(() {
      _requested = true;
      _phase = VideoNotePhase.loading;
    });
    try {
      final resolved = await (widget.resolveSource?.call(id) ?? _resolve(id));
      if (!mounted || gen != _gen) return;
      if (resolved == null) throw const FileUnavailable();
      final (source, isFile) = resolved;

      final playback = widget.playbackFactory?.call(source, isFile) ??
          VideoNotePlayerController(source: source, isFile: isFile);
      try {
        await playback.load().timeout(_loadTimeout);
      } catch (e) {
        playback.dispose();
        rethrow;
      }
      if (!mounted || gen != _gen) {
        playback.dispose();
        return;
      }
      playback.addListener(_onTick);
      _playback = playback;
      setState(() => _phase = VideoNotePhase.ready);
      // Playing straight away is the point: the tap that loaded this was a tap
      // that asked to watch it. A note that loaded and then waited for a second
      // tap would read as a bubble that ignored the first.
      await playback.play();
    } on FileUnavailable {
      if (!mounted || gen != _gen) return;
      setState(() => _phase = VideoNotePhase.unavailable);
    } catch (e) {
      debugPrint('VideoNoteMessage: ${widget.storageId} failed to load: $e');
      if (!mounted || gen != _gen) return;
      setState(() => _phase = VideoNotePhase.failed);
    }
  }

  /// The real resolution: a local copy if one of the video caches already has
  /// it, otherwise a signed URL. Lookup only, never a download — the same
  /// contract `VideoPlayerSurface` keeps, so scrolling past a note never costs
  /// a fetch nobody asked for.
  Future<(String, bool)?> _resolve(String id) async {
    final local = await VideoFileCache.instance.lookup(id);
    if (local != null) return (local, true);
    final url = await FileUrlCache.instance
        .resolve(id, () => widget.api.getFileUrl(id))
        .timeout(_loadTimeout);
    return url == null ? null : (url, false);
  }

  void _onTap() {
    switch (_phase) {
      case VideoNotePhase.unavailable:
        return;
      case VideoNotePhase.failed:
        HapticFeedback.selectionClick();
        final id = widget.storageId;
        // A stale signed URL is the likeliest reason a second attempt works
        // where the first didn't — the same invalidation `AudioMessage._retry`
        // makes for the same reason.
        if (id != null) FileUrlCache.instance.invalidate(id);
        unawaited(_load());
      case VideoNotePhase.loading:
        if (!_requested) unawaited(_load());
      case VideoNotePhase.ready:
        final p = _playback;
        if (p == null) return;
        // `isCompleted` is checked FIRST, before `isPlaying`, and that order is
        // the whole bug. `video_player` does not clear `isPlaying` when a clip
        // finishes — it reports `playing: true` at the end and stays there — so
        // reading `isPlaying` first sends the tap down the pause branch on a
        // note that stopped seconds ago. The visible symptom is a play glyph
        // that ignores the first tap and needs a second one to replay, which is
        // exactly what `audio_message.dart` shipped once and documents at
        // length. The rewind is the other half: without it the player is
        // already at the end and `play()` returns having done nothing.
        if (p.isCompleted) {
          unawaited(p.seekToStart().then((_) => p.play()));
          return;
        }
        if (p.isPlaying) {
          unawaited(p.pause());
        } else {
          unawaited(p.play());
        }
    }
  }

  Duration get _total {
    final fromPlayer = _playback?.duration ?? Duration.zero;
    if (fromPlayer > Duration.zero) return fromPlayer;
    final ms = widget.durationMs;
    return ms == null ? Duration.zero : Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final size = widget.diameter;
    final p = _playback;
    final display = videoNoteDisplayFor(
      rawPlaying: p?.isPlaying ?? false,
      completed: p?.isCompleted ?? false,
      position: p?.position ?? Duration.zero,
      total: _total,
    );

    final Widget face;
    if (_phase == VideoNotePhase.ready && p != null) {
      face = p.view();
    } else if (widget.posterStorageId != null) {
      face = RemoteImage(
        storageId: widget.posterStorageId!,
        api: widget.api,
        fit: BoxFit.cover,
      );
    } else {
      face = ColoredBox(color: theme.surfaceSunken);
    }

    final semanticLabel = switch (_phase) {
      VideoNotePhase.unavailable => l10n.videoNoteMessageUnavailableLabel,
      VideoNotePhase.failed => l10n.videoNoteMessageRetryLabel,
      VideoNotePhase.loading => l10n.videoNoteMessageLoadingLabel,
      VideoNotePhase.ready => display.playing
          ? l10n.videoNoteMessagePauseLabel
          : l10n.videoNoteMessagePlayLabel,
    };

    return Semantics(
      button: true,
      label: semanticLabel,
      value: formatClockDuration(display.remaining),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipOval(child: face),
              // Only over a picture, and only while the note is not playing:
              // the glyph and the readout have to survive whatever the first
              // frame happens to look like, and a scrim over live video would
              // be a permanent grey wash on the thing people are watching.
              if (!display.playing)
                const ClipOval(
                  child: ColoredBox(color: Color(0x40000000)),
                ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _NoteRingPainter(
                    progress: display.progress,
                    track: Colors.white.withValues(alpha: 0.25),
                    ink: theme.accent,
                  ),
                ),
              ),
              _overlay(theme, display),
            ],
          ),
        ),
      ),
    );
  }

  /// The glyph and the duration, both inside the circle.
  Widget _overlay(AppTheme theme, VideoNoteDisplay display) {
    final l10n = AppLocalizations.of(context);
    if (_phase == VideoNotePhase.unavailable) {
      return Center(
        child: Icon(Icons.videocam_off_outlined,
            color: Colors.white.withValues(alpha: 0.9), size: 30),
      );
    }
    if (_phase == VideoNotePhase.failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh, color: Colors.white, size: 30),
            const SizedBox(height: 4),
            Text(
              l10n.videoNoteMessageRetryHint,
              style: theme.monoTiny.copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    }
    if (_phase == VideoNotePhase.loading && _requested) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.accent),
        ),
      );
    }

    return Stack(
      children: [
        if (!display.playing)
          Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
            ),
          ),
        // Bottom of the circle rather than dead centre, so it never sits on the
        // face — the one thing a video note always has in the middle of it.
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.diameter * 0.11,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                formatClockDuration(display.remaining),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The playback ring drawn just inside the circle's edge.
class _NoteRingPainter extends CustomPainter {
  const _NoteRingPainter({
    required this.progress,
    required this.track,
    required this.ink,
  });

  final double progress;
  final Color track;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final circle = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      circle,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      circle,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_NoteRingPainter old) =>
      old.progress != progress || old.ink != ink || old.track != track;
}

/// The outgoing circle: the poster (or a plain disc) with an upload arc over
/// it, so a note on its way up holds exactly the geometry the finished one
/// will take and the transcript does not jump when the upload lands.
///
/// Deliberately a separate widget rather than a mode of [VideoNoteMessage]:
/// an uploading note has no storage id, and every code path in there begins by
/// resolving one.
class OutboundVideoNote extends StatelessWidget {
  const OutboundVideoNote({
    super.key,
    required this.theme,
    required this.diameter,
    required this.failed,
    required this.progress,
    this.posterBytes,
    this.onRetry,
    this.onDiscard,
  });

  final AppTheme theme;
  final double diameter;
  final bool failed;

  /// 0..1, or null for an indeterminate upload (the web, where the transport
  /// reports nothing until it is done).
  final double? progress;
  final Uint8List? posterBytes;
  final Future<void> Function()? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final poster = posterBytes;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: poster == null
                ? ColoredBox(color: theme.surfaceSunken)
                : Image.memory(poster, fit: BoxFit.cover),
          ),
          const ClipOval(child: ColoredBox(color: Color(0x59000000))),
          if (!failed)
            Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: progress,
                  color: Colors.white,
                ),
              ),
            )
          else
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onRetry != null)
                    _circleAction(
                      icon: Icons.refresh,
                      label: l10n.videoNoteMessageRetryLabel,
                      onTap: () => onRetry!(),
                    ),
                  if (onRetry != null && onDiscard != null)
                    const SizedBox(width: 10),
                  if (onDiscard != null)
                    _circleAction(
                      icon: Icons.close,
                      label: l10n.videoNoteMessageDiscardLabel,
                      onTap: onDiscard!,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
