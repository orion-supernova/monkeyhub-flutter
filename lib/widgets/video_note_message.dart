import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../composer/capture_recorder.dart' show videoNoteContentType;
import '../media/file_url_cache.dart';
import '../media/video_file_cache.dart';
import '../media/view_once_fetch.dart' show ViewOnceOpener;
import '../media/view_once_media.dart';
import '../keyboard/focusable_tap.dart';
import '../privacy/capture_protection.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../screens/view_once_viewer.dart' show ViewOnceBadge;
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'glass_buttons.dart';
import 'glass_reveal.dart' show GlassStill;
import 'liquid_glass.dart' show GlassTone, MediaGlass;
import 'photo_chrome.dart';
import 'capture_shield.dart';
import 'dust/spoiler_dust.dart';
import 'dust_dissolve.dart';
import 'remote_image.dart';
import 'view_once_seal.dart';

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
  // Rounded UP to the second. The position moves every frame now, and a
  // floored countdown drops from 0:05 to 0:04 one frame after five seconds
  // were left — a second early, every second.
  final left = (total - clamped).inMilliseconds;
  return VideoNoteDisplay(
    playing: rawPlaying,
    progress: (clamped.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0),
    remaining: Duration(seconds: (left / 1000).ceil()),
  );
}

/// The rates the focus's speed pill cycles through.
///
/// No remembered rate: a speed lasts for one sitting in [VideoNoteFocus]
/// (carried across the notes autoplay runs through) and is back to 1× the
/// next time a note is opened.
abstract final class VideoNoteSpeed {
  static const steps = [1.0, 1.5, 2.0];

  /// The rate after [speed] in the pill's cycle: 1× → 1.5× → 2× → 1×.
  static double after(double speed) {
    final i = steps.indexOf(speed);
    return steps[(i + 1) % steps.length];
  }

  /// "1×", "1.5×", "2×".
  static String label(double speed) {
    final whole = speed == speed.roundToDouble();
    return '${whole ? speed.toInt() : speed}×';
  }
}

/// A note further down the chat, for [VideoNoteFocus]'s autoplay to carry on
/// into: enough to open it, plus a way to bring its bubble on screen behind
/// the focus so the circle has somewhere to fly home to.
@immutable
class VideoNoteRef {
  const VideoNoteRef({
    required this.storageId,
    this.posterStorageId,
    this.durationMs,
    this.reveal,
  });

  final String storageId;
  final String? posterStorageId;
  final int? durationMs;
  final VoidCallback? reveal;
}

/// Which note the open focus is showing, and the bubbles on screen that could
/// be it — both by storage id.
///
/// Statics, not something threaded through the tree: there is one screen and
/// at most one focus on it, and autoplay moves the focus onto notes whose
/// bubbles it never had a reference to.
abstract final class _VideoNoteStage {
  static final ValueNotifier<String?> showing = ValueNotifier(null);
  static final Map<String, _VideoNoteMessageState> bubbles = {};

  static Rect? rectFor(String storageId) =>
      bubbles[storageId]?._circleRect();
}

/// How fast a drag around the focused circle moves through the note.
///
/// The circle's answer to YouTube's "slide up for precise seeking": the
/// further the finger is from the centre, the slower the scrub. The geometry
/// already pushes the same way (an inch of arc far out is a smaller angle
/// than an inch near the rim), and the rate multiplies it, so a finger well
/// clear of the circle moves through a 60-second note a frame at a time.
enum VideoNoteScrubRate {
  full(1),
  half(0.5),
  fine(0.25);

  const VideoNoteScrubRate(this.gain);
  final double gain;
}

/// The rate band a finger [distance] from the centre of a circle of [radius]
/// falls in. [current] adds hysteresis, so a finger resting on a boundary
/// does not flicker between two rates and buzz the haptics.
VideoNoteScrubRate videoNoteScrubRateFor(
  double distance,
  double radius, {
  VideoNoteScrubRate? current,
}) {
  const halfFrom = 1.35;
  const fineFrom = 1.9;
  final slack = current == null ? 0.0 : 0.08;
  final r = distance / radius;
  return switch (current) {
    VideoNoteScrubRate.full when r < halfFrom + slack => VideoNoteScrubRate.full,
    VideoNoteScrubRate.fine when r > fineFrom - slack => VideoNoteScrubRate.fine,
    VideoNoteScrubRate.half
        when r > halfFrom - slack && r < fineFrom + slack =>
      VideoNoteScrubRate.half,
    _ => r < halfFrom
        ? VideoNoteScrubRate.full
        : (r < fineFrom ? VideoNoteScrubRate.half : VideoNoteScrubRate.fine),
  };
}

/// The signed angle from [from] to [to], wrapped to (-π, π]: clockwise
/// positive in screen coordinates. Without the wrap, crossing 9 o'clock
/// (where `atan2` jumps from π to -π) reads as a whole turn backwards.
double videoNoteAngleDelta(double from, double to) {
  var d = to - from;
  while (d > math.pi) {
    d -= math.pi * 2;
  }
  while (d <= -math.pi) {
    d += math.pi * 2;
  }
  return d;
}

/// Where a scrub that started at [from] lands after the finger turned [turn]
/// radians at [rate]. One full turn at full rate is the whole note, matching
/// the ring, which is the whole note.
Duration videoNoteScrubBy({
  required Duration from,
  required double turn,
  required VideoNoteScrubRate rate,
  required Duration total,
}) {
  if (total <= Duration.zero) return Duration.zero;
  final deltaMs = total.inMilliseconds * turn / (math.pi * 2) * rate.gain;
  final ms = (from.inMilliseconds + deltaMs)
      .round()
      .clamp(0, total.inMilliseconds);
  return Duration(milliseconds: ms);
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
  Future<void> seekTo(Duration position);

  /// 1, 1.5 or 2 — see [VideoNoteSpeed].
  Future<void> setSpeed(double speed);

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
  Future<void> seekTo(Duration position) async => _controller?.seekTo(position);

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _controller?.setPlaybackSpeed(speed);
    } catch (e) {
      // A platform that cannot change rate keeps playing at 1×, which is a
      // worse note, not a broken one.
      debugPrint('VideoNotePlayerController.setSpeed($speed): $e');
    }
  }

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

/// A video note: a circular bubble that lifts into [VideoNoteFocus] to play.
///
/// Deliberately NOT the fullscreen video path. A note is a glance — a few
/// seconds of somebody's face — and a full-screen player with its own chrome
/// is too much ceremony for it. A tap grows the same circle to the middle of
/// the screen over a dimmed chat, where it has room for a speed pill, a pause
/// button and a ring big enough to scrub; closing flies it back into place,
/// paused where it was left, with the ring showing how far it got.
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
    this.upNext,
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

  /// The notes after this one in the chat, asked for when the focus opens.
  /// Null (or empty) and the note simply ends.
  final List<VideoNoteRef> Function()? upNext;

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

  /// The circle in the transcript, measured so [VideoNoteFocus] can fly from
  /// and back to it.
  final GlobalKey _circleKey = GlobalKey();

  /// Set while a focus this bubble opened is up, with this bubble's player in
  /// it. If the bubble goes first the focus is told to release the player.
  VideoNoteHandoff? _handoff;

  /// While the focus shows this note (flight included) the circle here is a
  /// gap: two copies of one face would read as two notes, and on the web the
  /// player is a platform view that can only be in one place.
  bool get _focused {
    final id = widget.storageId;
    return id != null && _VideoNoteStage.showing.value == id;
  }

  @override
  void initState() {
    super.initState();
    _register();
    _VideoNoteStage.showing.addListener(_onStage);
  }

  @override
  void didUpdateWidget(covariant VideoNoteMessage old) {
    super.didUpdateWidget(old);
    if (old.storageId == widget.storageId) return;
    // `message_bubble.dart` builds this with no key, so the ListView recycles
    // one State onto a different message. Without this the circle keeps playing
    // — and counting down — the previous note.
    _unregister(old.storageId);
    _register();
    _gen++;
    _disposePlayback();
    setState(() {
      _phase = VideoNotePhase.loading;
      _requested = false;
    });
  }

  @override
  void dispose() {
    _VideoNoteStage.showing.removeListener(_onStage);
    _unregister(widget.storageId);
    _disposePlayback();
    super.dispose();
  }

  void _register() {
    final id = widget.storageId;
    if (id != null) _VideoNoteStage.bubbles[id] = this;
  }

  void _unregister(String? id) {
    if (id != null && identical(_VideoNoteStage.bubbles[id], this)) {
      _VideoNoteStage.bubbles.remove(id);
    }
  }

  void _onStage() {
    if (mounted) setState(() {});
  }

  void _disposePlayback() {
    final p = _playback;
    _playback = null;
    p?.removeListener(_onTick);
    final handoff = _handoff;
    _handoff = null;
    if (handoff != null) {
      // A focus is still showing (or may come back to) this player — autoplay
      // scrolled the chat and recycled this row, typically. It releases it.
      handoff.orphaned = true;
      return;
    }
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
      // Opening straight away is the point: the tap that loaded this was a tap
      // that asked to watch it. A note that loaded and then waited for a second
      // tap would read as a bubble that ignored the first.
      unawaited(_openFocus());
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
  /// Opens a note further down the chat for the focus's autoplay: the same
  /// resolve and the same player this bubble would use for its own.
  Future<VideoNotePlayback> _openRef(VideoNoteRef note) async {
    final id = note.storageId;
    final resolved = await (widget.resolveSource?.call(id) ?? _resolve(id));
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
    return playback;
  }

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
        unawaited(_openFocus());
    }
  }

  /// Lifts the note into [VideoNoteFocus] and plays it there; pauses it when
  /// the focus closes, and shows it here again once the flight back has
  /// landed.
  Future<void> _openFocus() async {
    final p = _playback;
    final id = widget.storageId;
    if (p == null || id == null || _handoff != null || !mounted) return;
    // A finished note reopens from the top. Without the rewind the player is
    // already at the end and `play()` returns having done nothing — the bug
    // `audio_message.dart` documents.
    if (p.isCompleted) await p.seekToStart();
    await p.setSpeed(VideoNoteSpeed.steps.first);
    if (!mounted || _playback != p || _handoff != null) return;
    final handoff = VideoNoteHandoff();
    final route = VideoNoteFocus.route(
      context,
      playback: p,
      storageId: id,
      fallbackTotal: _total,
      rectFor: _VideoNoteStage.rectFor,
      handoff: handoff,
      upNext: widget.upNext?.call() ?? const [],
      open: _openRef,
      // Measured now, while the circle is still laid out: the first frame of
      // the flight builds before the placeholder that replaces it has a size.
      initialSource: _circleRect(),
    );
    _handoff = handoff;
    _VideoNoteStage.showing.value = id;
    unawaited(p.play());
    unawaited(Navigator.of(context, rootNavigator: true).push(route));
    await route.completed;
    if (mounted && identical(_handoff, handoff)) _handoff = null;
  }

  /// The circle's rect in global coordinates, or null when it is gone (its
  /// row scrolled out and was recycled while the focus was open).
  Rect? _circleRect() {
    if (!mounted) return null;
    final box = _circleKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Duration get _total {
    final fromPlayer = _playback?.duration ?? Duration.zero;
    if (fromPlayer > Duration.zero) return fromPlayer;
    final ms = widget.durationMs;
    return ms == null ? Duration.zero : Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.diameter;
    // The key sits on a box that exists in both states. Swapping in a fresh
    // placeholder instead would hand the flight's first frame a render box
    // with a size but no position yet, and the circle would leave from the
    // top-left corner.
    return SizedBox(
      key: _circleKey,
      width: size,
      height: size,
      child: _focused ? null : _bubble(context),
    );
  }

  Widget _bubble(BuildContext context) {
    final size = widget.diameter;
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
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
        child: Icon(
          CupertinoIcons.slash_circle,
          color: Colors.white.withValues(alpha: 0.9),
          size: 30,
        ),
      );
    }
    if (_phase == VideoNotePhase.failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.arrow_clockwise,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            // The body face at 13 — the mono slot is tracked typewriter
            // on a character theme.
            Text(
              sentenceCaseOf(context, l10n.videoNoteMessageRetryHint),
              style: theme.body.copyWith(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
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
          child: CupertinoActivityIndicator(radius: 13, color: theme.inkMuted),
        ),
      );
    }

    return Stack(
      children: [
        if (!display.playing) const Center(child: MediaPlayDisc(size: 46)),
        // Bottom of the circle rather than dead centre, so it never sits on the
        // face — the one thing a video note always has in the middle of it.
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.diameter * 0.11,
          child: Center(
            child: MediaDurationBadge(duration: display.remaining),
          ),
        ),
      ],
    );
  }
}

/// A play-once video note: the same circle as [VideoNoteMessage], sealed.
///
/// Never the real poster: that is the sender's face. An armed send carries a
/// sixteen-pixel stand-in instead (`viewOnceMicroPoster`), drawn up to the
/// circle and blurred until only its colours survive, under a twinkling dust
/// of specks — Telegram's sealed note. A note with no stand-in (sent before
/// there was one) gets a dark accent-tinted field under the same dust. Then a
/// dark play button with the view-once "1" on its corner, and the length.
///
/// The stand-in is fetched into memory and drawn with [Image.memory]: never
/// [RemoteImage], whose disk cache this whole family of bubbles stays away
/// from.
///
/// A tap spends the watch through [onOpen], stages the bytes in a
/// [ViewOnceMedia] (never the video caches), and flies the circle into
/// [VideoNoteFocus] in its `once` mode. When the focus closes — at the end of
/// the note, on a tap outside, or when the app leaves the foreground — the
/// player is released, the staged copy deleted, and the circle comes back as
/// played. Nothing here can lead anywhere else: no up-next, no autoplay into
/// it from a neighbour (it has no storage id for `_videoNotesAfter` to find),
/// and no scrub or replay in the focus.
///
/// Sealed, played and expired are one circle, the same size as a real note,
/// so the transcript holds still as one becomes the other.
class ViewOnceVideoNote extends StatefulWidget {
  const ViewOnceVideoNote({
    super.key,
    required this.messageId,
    required this.isMine,
    required this.durationMs,
    required this.opened,
    required this.burned,
    this.selfChat = false,
    this.api,
    this.posterStorageId,
    this.diameter = 180,
    this.onOpen,
    this.playbackFactory,
    this.posterLoader,
    this.seedKey,
  });

  /// What seeds the disc's dust and colour field, when it is not
  /// [messageId]: the bubble passes the send's client id, which the upload's
  /// circle used too, so the sent circle carries on from it grain for grain.
  final String? seedKey;

  /// Seeds the sealed disc's colour field, keys the focus's flight, and tells
  /// a recycled row it now shows a different note.
  final String messageId;
  final bool isMine;

  /// Recorded length, kept on an armed send so the seal can say it.
  final int? durationMs;

  /// This viewer has had their watch.
  final bool opened;

  /// The server has deleted the video for everyone.
  final bool burned;

  /// Sent into the sender's own Saved Messages ([ChatMessage.viewOnceSelf]):
  /// the sender's copy is sealed there, and opens once, like a recipient's.
  final bool selfChat;

  /// Resolves [posterStorageId]. Null draws the fallback field.
  final ChatApi? api;

  /// The micro poster: at most sixteen pixels a side.
  final String? posterStorageId;

  final double diameter;

  /// Spends the watch and hands back the bytes. Null leaves the disc inert.
  final ViewOnceOpener? onOpen;

  /// Builds the playback. Null uses `video_player`; tests pass a fake.
  @visibleForTesting
  final VideoNotePlayback Function(String source, bool isFile)? playbackFactory;

  /// Fetches the micro poster's bytes. Null uses [api]; tests pass a fake.
  @visibleForTesting
  final Future<Uint8List?> Function(String storageId)? posterLoader;

  @override
  State<ViewOnceVideoNote> createState() => _ViewOnceVideoNoteState();
}

class _ViewOnceVideoNoteState extends State<ViewOnceVideoNote> {
  Uint8List? _poster;
  /// [VideoNoteMessage]'s ceiling, for the same stalled-source failure.
  static const _loadTimeout = Duration(seconds: 45);

  final GlobalKey _circleKey = GlobalKey();

  /// The face (field, poster, dim, dust) under every state of the disc, kept
  /// across sealed, sender's and played so a change between them animates
  /// in place instead of rebuilding.
  final GlobalKey _faceKey = GlobalKey();

  String get _key => widget.seedKey ?? widget.messageId;
  int get _seed => _key.hashCode;

  /// Came up where the upload's circle (same seed) was showing a moment ago:
  /// the words fade in where the progress ring was, rather than popping.
  late final bool _carriedOn = SpoilerDust.wasShowing(_seed);

  /// Between the tap and the flight: the fetch, the staging, the load.
  bool _busy = false;

  /// This circle has been watched (or the watch was spent and could not
  /// play). The message flag says the same once the repository catches up.
  bool _done = false;

  /// The player, while a focus this circle opened is showing it.
  VideoNotePlayback? _playback;
  VideoNoteHandoff? _handoff;

  int _gen = 0;

  /// Its own namespace on the stage, so it can never be mistaken for a real
  /// note's storage id.
  String get _stageKey => 'once:${widget.messageId}';

  bool get _focused => _VideoNoteStage.showing.value == _stageKey;

  bool get _spent =>
      _done || widget.opened || widget.burned || _sendersCopy;

  /// The sender's own copy, spent from the start — except in Saved Messages.
  bool get _sendersCopy => widget.isMine && !widget.selfChat;

  bool get _openable =>
      widget.onOpen != null && !_busy && _handoff == null && !_spent;

  @override
  void initState() {
    super.initState();
    _VideoNoteStage.showing.addListener(_onStage);
    _loadPoster();
  }

  @override
  void didUpdateWidget(covariant ViewOnceVideoNote old) {
    super.didUpdateWidget(old);
    if (old.posterStorageId != widget.posterStorageId) _loadPoster();
    if (old.messageId == widget.messageId) return;
    _gen++;
    _release();
    _busy = false;
    _done = false;
  }

  @override
  void dispose() {
    _VideoNoteStage.showing.removeListener(_onStage);
    _gen++;
    _release();
    super.dispose();
  }

  Future<void> _loadPoster() async {
    final id = widget.posterStorageId;
    final key = _key;
    // By storage id, or failing that by the message: what the upload's
    // circle drew (the very same sixteen pixels), or what this session
    // decoded before the server deleted it on the burn.
    _poster = (id == null ? null : _MicroPosters.peek(id)) ??
        _MicroPosters.peekKey(key);
    if (_poster != null) {
      if (id != null) _MicroPosters.rememberId(id, _poster!);
      return;
    }
    if (id == null) return;
    final bytes = await _MicroPosters.load(
      id,
      widget.posterLoader ?? _fetchPoster,
    );
    if (bytes != null) _MicroPosters.rememberKey(key, bytes);
    if (!mounted || widget.posterStorageId != id || bytes == null) return;
    setState(() => _poster = bytes);
  }

  Future<Uint8List?> _fetchPoster(String id) async {
    final api = widget.api;
    if (api == null) return null;
    final url = await api.getFileUrl(id);
    if (url == null) return null;
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    // Anything heavier than a micro poster is not one; draw the field.
    if (res.statusCode != 200 ||
        res.bodyBytes.length > kViewOnceMicroPosterMaxBytes) {
      return null;
    }
    return res.bodyBytes;
  }

  void _onStage() {
    if (mounted) setState(() {});
  }

  /// Lets go of the player — or, while a focus is still showing it, hands it
  /// to the focus to release, as [VideoNoteMessage] does.
  void _release() {
    final p = _playback;
    _playback = null;
    final handoff = _handoff;
    _handoff = null;
    if (handoff != null) {
      handoff.orphaned = true;
      return;
    }
    p?.dispose();
  }

  Duration get _total {
    final ms = widget.durationMs;
    return ms == null || ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
  }

  Rect? _circleRect() {
    if (!mounted) return null;
    final box = _circleKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _open() async {
    if (!_openable) return;
    final gen = ++_gen;
    setState(() => _busy = true);
    Uint8List? bytes = await widget.onOpen!();
    if (!mounted || gen != _gen) return;
    if (bytes == null) {
      // The opener has said why. The message flags will redraw the disc.
      setState(() => _busy = false);
      return;
    }
    ViewOnceMedia? media;
    VideoNotePlayback? playback;
    try {
      media = await ViewOnceMedia.stage(
        bytes,
        contentType: videoNoteContentType,
        extension: 'mp4',
      );
      // Ours was the last reference; the staged copy is the only one now.
      bytes = null;
      final inner = widget.playbackFactory?.call(media.source, media.isFile) ??
          VideoNotePlayerController(source: media.source, isFile: media.isFile);
      playback = _ReleasingPlayback(inner, media);
      await playback.load().timeout(_loadTimeout);
      if (!mounted ||
          gen != _gen ||
          _backgrounded()) {
        throw StateError('view-once note: gone before it could play');
      }
    } catch (e) {
      debugPrint('ViewOnceVideoNote: ${widget.messageId}: $e');
      // Releasing the playback releases the staged copy with it.
      if (playback != null) {
        playback.dispose();
      } else {
        unawaited(media?.release());
      }
      // The watch was spent when the server handed out the ticket, so there
      // is nothing to retry: the circle goes straight to played.
      if (mounted && gen == _gen) {
        setState(() {
          _busy = false;
          _done = true;
        });
      }
      return;
    }
    _playback = playback;
    setState(() => _busy = false);
    await _focus(playback, gen);
  }

  /// The app left the foreground while the bytes were on their way: the look
  /// ends there, as it would have had it been playing. Unknown (no lifecycle
  /// reported yet) counts as present.
  bool _backgrounded() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state != null && state != AppLifecycleState.resumed;
  }

  /// Flies the note into the focus and plays it through once; comes back as
  /// played — under the focus's dust, normally, or by the flight home when
  /// the burn is skipped.
  Future<void> _focus(VideoNotePlayback p, int gen) async {
    final key = _stageKey;
    // Played from the moment the focus starts to burn, so the circle under
    // the dust is already the spent one.
    final handoff = VideoNoteHandoff()
      ..onBurn = () {
        if (mounted && gen == _gen) setState(() => _done = true);
      };
    final route = VideoNoteFocus.route(
      context,
      playback: p,
      storageId: key,
      fallbackTotal: _total,
      // Only ever this circle, and only while it still shows this note.
      rectFor: (id) =>
          id == key && _stageKey == key ? _circleRect() : null,
      handoff: handoff,
      initialSource: _circleRect(),
      once: true,
    );
    _handoff = handoff;
    _VideoNoteStage.showing.value = key;
    unawaited(p.play());
    unawaited(Navigator.of(context, rootNavigator: true).push(route));
    await route.completed;
    // Gone or recycled while the focus was up: `_release` marked the handoff
    // orphaned and the focus has released the player itself.
    if (!mounted || !identical(_handoff, handoff)) return;
    _handoff = null;
    final played = _playback;
    _playback = null;
    // After the frame that stops drawing it, like the focus's own players.
    SchedulerBinding.instance.addPostFrameCallback((_) => played?.dispose());
    if (gen == _gen) setState(() => _done = true);
  }

  /// The one line under the seal — the photo tile's three facts, in the
  /// words a voice or video note takes.
  String _caption(AppLocalizations l10n) {
    if (widget.burned) {
      return widget.opened || _done || _sendersCopy
          ? l10n.messageBubblePlayOncePlayed
          : l10n.messageBubbleViewOnceExpired;
    }
    if (widget.opened || _done) return l10n.messageBubblePlayOncePlayed;
    if (_sendersCopy) return l10n.messageBubblePlayOnceLabel;
    return l10n.messageBubblePlayOnceTapToPlay;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.diameter;
    // A gap while the focus shows this note, for [VideoNoteMessage]'s reason:
    // two copies of the circle would read as two notes.
    return SizedBox(
      key: _circleKey,
      width: size,
      height: size,
      child: _focused ? null : _disc(context),
    );
  }

  Widget _disc(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final size = widget.diameter;
    final spent = _spent && !_busy;
    final total = _total;

    if (spent) return _spentDisc(theme, l10n, size, total);

    // A Telegram-sized play button: 44pt at Telegram's 200pt circle, and in
    // proportion either side of it.
    final button = (size * 0.22).clamp(36.0, 52.0);
    final poster = _poster;
    final disc = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _OnceFace(
            key: _faceKey,
            seed: _seed,
            tint: theme.accent,
            poster: poster,
            dust: true,
            ghost: false,
          ),
          Center(
            child: SizedBox(
              width: button + 8,
              height: button + 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Container(
                      width: button,
                      height: button,
                      decoration: const BoxDecoration(
                        color: Color(0x73000000),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: _busy
                          ? const CupertinoActivityIndicator(
                              radius: 9,
                              color: Colors.white,
                            )
                          : Icon(
                              CupertinoIcons.play_fill,
                              color: Colors.white,
                              size: button * 0.42,
                            ),
                    ),
                  ),
                  const PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: ViewOnceCornerBadge(
                      color: Colors.white,
                      knockout: Color(0xFF111114),
                      ring: Color(0x73000000),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom-leading, where Telegram keeps it, with the dot that says
          // nobody has watched it yet.
          if (total > Duration.zero)
            PositionedDirectional(
              start: size * 0.2,
              bottom: size * 0.12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MediaDurationBadge(duration: total),
                  if (!_sendersCopy) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    if (!_openable) return disc;
    return FocusableTap(
      onTap: _open,
      semanticLabel: l10n.messageBubblePlayOnceVideoNoteSemanticLabel,
      shape: FocusRingShape.circle,
      radius: size / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: disc,
      ),
    );
  }

  /// Played, expired, or the sender's own. One face with the sealed disc:
  /// the same blurred stand-in (or colour field), so the circle keeps its
  /// colour; dimmed to a ghost once the watch is spent, with the struck seal
  /// and the one word that says why. The sender's copy, still unwatched, keeps
  /// the dust: for everyone else it is still sealed.
  Widget _spentDisc(
    AppTheme theme,
    AppLocalizations l10n,
    double size,
    Duration total,
  ) {
    final seal = (size * 0.26).clamp(36.0, 56.0);
    final live = _sendersCopy && !widget.burned && !widget.opened && !_done;
    final ink = live ? Colors.white : const Color(0xD9FFFFFF);
    final words = Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size * 0.14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ViewOnceSeal(color: ink, struck: !live, size: seal),
            const SizedBox(height: 6),
            Text(
              _caption(l10n),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.body.copyWith(
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: ink,
                decoration: TextDecoration.none,
                shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
              ),
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _OnceFace(
            key: _faceKey,
            seed: _seed,
            tint: theme.accent,
            poster: _poster,
            dust: live,
            ghost: !live,
          ),
          // Where the upload's ring was a moment ago: in, not popped.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _carriedOn ? 0 : 1, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (context, v, child) => Opacity(opacity: v, child: child),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(live), child: words),
            ),
          ),
          if (total > Duration.zero)
            Positioned(
              left: 0,
              right: 0,
              bottom: size * 0.11,
              child: Center(
                child: Text(
                  formatClockDuration(total),
                  style: theme.body.copyWith(
                    fontSize: 12,
                    height: 1.2,
                    color: ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The face of a play-once circle, under every state of it and under the
/// upload's circle too: the accent field, the stand-in blurred to its colours
/// over it once decoded (crossfaded in, never popped), a dim (light while
/// sealed, deep once spent, animated between), and the spoiler dust (faded
/// in and out, never cut).
class _OnceFace extends StatelessWidget {
  const _OnceFace({
    super.key,
    required this.seed,
    required this.tint,
    required this.poster,
    required this.dust,
    required this.ghost,
  });

  final int seed;
  final Color tint;
  final Uint8List? poster;
  final bool dust;

  /// Spent: dimmed to about two fifths of its brightness.
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final bytes = poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The fallback field always, the poster over it once decoded: a
        // frame of transcript showing through a circle mid-decode would read
        // as a hole.
        ClipOval(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SealedNotePainter(seed: seed, tint: tint),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          // Tight, like the rest of the face: the default layout loosens,
          // and a loose image sits at its sixteen pixels.
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, ?current],
          ),
          child: bytes == null
              ? const SizedBox.expand()
              : ClipOval(
                  key: ValueKey(identityHashCode(bytes)),
                  // Sixteen pixels drawn up to the circle is already mush;
                  // the blur takes the last of the edges off it. Static, so
                  // the boundary rasterises it once.
                  child: RepaintBoundary(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 20,
                        sigmaY: 20,
                        tileMode: TileMode.mirror,
                      ),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
        ),
        // A touch of dark so the specks and the button read over a bright
        // frame; most of the light taken once the watch is spent.
        TweenAnimationBuilder<double>(
          tween: Tween(end: ghost ? 0.6 : 0.2),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
          builder: (context, a, _) => ClipOval(
            child: ColoredBox(color: Color.fromRGBO(0, 0, 0, a)),
          ),
        ),
        // Telegram's spoiler: the shared field, kept to the circle without a
        // clip, ticking only while it shows.
        SpoilerDust(oval: true, seed: seed, brightness: 1.35, active: dust),
      ],
    );
  }
}

/// Micro posters, in memory, by storage id. A handful of sixteen-pixel JPEGs —
/// a few hundred bytes each — so a small bound is plenty, and nothing of them
/// is ever written to disk.
abstract final class _MicroPosters {
  static const _cap = 64;
  static final Map<String, Uint8List> _bytes = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

  static Uint8List? peek(String id) => _bytes[id];

  /// By message (the send's client id, or the message id), for the session:
  /// the upload's circle leaves its bytes here for the sent circle, and a
  /// note keeps its colours after the burn deletes the stored copy.
  static final Map<String, Uint8List> _byKey = {};

  static Uint8List? peekKey(String key) => _byKey[key];

  static void rememberKey(String key, Uint8List bytes) {
    if (identical(_byKey[key], bytes)) return;
    if (_byKey.length >= _cap) _byKey.remove(_byKey.keys.first);
    _byKey[key] = bytes;
  }

  static void rememberId(String id, Uint8List bytes) {
    if (_bytes.containsKey(id)) return;
    if (_bytes.length >= _cap) _bytes.remove(_bytes.keys.first);
    _bytes[id] = bytes;
  }

  static Future<Uint8List?> load(
    String id,
    Future<Uint8List?> Function(String id) fetch,
  ) {
    final have = _bytes[id];
    if (have != null) return Future.value(have);
    return _inflight[id] ??= () async {
      try {
        final bytes = await fetch(id);
        if (bytes != null) {
          if (_bytes.length >= _cap) _bytes.remove(_bytes.keys.first);
          _bytes[id] = bytes;
        }
        return bytes;
      } catch (e) {
        debugPrint('ViewOnceVideoNote: micro poster $id: $e');
        return null;
      } finally {
        _inflight.remove(id);
      }
    }();
  }
}

/// A playback that deletes its staged copy when it is released, so the copy
/// goes with the player whoever ends up releasing it — the circle, or the
/// focus when the circle went first.
class _ReleasingPlayback implements VideoNotePlayback {
  _ReleasingPlayback(this._inner, this._media);

  final VideoNotePlayback _inner;
  final ViewOnceMedia _media;

  @override
  void addListener(VoidCallback listener) => _inner.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _inner.removeListener(listener);

  @override
  Future<void> load() => _inner.load();

  @override
  Duration get position => _inner.position;

  @override
  Duration get duration => _inner.duration;

  @override
  bool get isPlaying => _inner.isPlaying;

  @override
  bool get isCompleted => _inner.isCompleted;

  @override
  Future<void> play() => _inner.play();

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> seekToStart() => _inner.seekToStart();

  @override
  Future<void> seekTo(Duration position) => _inner.seekTo(position);

  @override
  Future<void> setSpeed(double speed) => _inner.setSpeed(speed);

  @override
  Widget view() => _inner.view();

  @override
  void dispose() {
    _inner.dispose();
    unawaited(_media.release());
  }
}

/// The sealed disc's face when there is no micro poster: a dark field with a
/// few soft, blurred pools of the accent in it, placed by the message id so
/// neighbouring notes differ.
///
/// Painted, not filtered — no `BackdropFilter`, no image — so there is nothing
/// of the sender in it to recover and nothing to re-rasterise per frame; the
/// [RepaintBoundary] around it caches the one paint.
class _SealedNotePainter extends CustomPainter {
  const _SealedNotePainter({required this.seed, required this.tint});

  final int seed;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Color.alphaBlend(
      tint.withValues(alpha: 0.22),
      const Color(0xFF15151A),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 0.95,
          colors: [base, const Color(0xFF0A0A0D)],
        ).createShader(rect),
    );
    final r = math.Random(seed);
    final d = size.shortestSide;
    final blur = MaskFilter.blur(BlurStyle.normal, d * 0.12);
    for (var i = 0; i < 3; i++) {
      final c = Offset(
        size.width * (0.2 + r.nextDouble() * 0.6),
        size.height * (0.2 + r.nextDouble() * 0.6),
      );
      final colour = i == 0
          ? tint.withValues(alpha: 0.38)
          : Color.lerp(tint, Colors.white, 0.35 * i)!
              .withValues(alpha: 0.14 + r.nextDouble() * 0.1);
      canvas.drawCircle(
        c,
        d * (0.18 + r.nextDouble() * 0.16),
        Paint()
          ..color = colour
          ..maskFilter = blur,
      );
    }
  }

  @override
  bool shouldRepaint(_SealedNotePainter old) =>
      old.seed != seed || old.tint != tint;
}

/// The focus's autoplay pill: no accent fill for on and off, the glyph
/// carries it, leading the label. On, two chevrons; off, the front chevron
/// folds into a stop bar. Both states stay full white: a dimmed pill reads as
/// one that cannot be tapped, not as one that is off. Turning it on kicks the
/// chevrons forward once. No idle loop: on resting chrome it distracts.
/// The pill eases between the two labels' widths rather than jumping.
class _AutoAdvanceToggle extends StatefulWidget {
  const _AutoAdvanceToggle({
    required this.on,
    required this.label,
    required this.semanticLabel,
    required this.height,
    required this.onTap,
  });

  final bool on;
  final String label;
  final String semanticLabel;
  final double height;
  final VoidCallback onTap;

  @override
  State<_AutoAdvanceToggle> createState() => _AutoAdvanceToggleState();
}

class _AutoAdvanceToggleState extends State<_AutoAdvanceToggle>
    with TickerProviderStateMixin {
  /// 1 on, 0 off: the fold.
  late final AnimationController _state = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.on ? 1 : 0,
  );

  /// The one-off forward kick when it turns on.
  late final AnimationController _kick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(_AutoAdvanceToggle old) {
    super.didUpdateWidget(old);
    if (old.on == widget.on) return;
    if (_calm) {
      _state.value = widget.on ? 1 : 0;
    } else if (widget.on) {
      _state.animateTo(1, curve: Curves.easeOutCubic);
      _kick.forward(from: 0);
    } else {
      _state.animateTo(0, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _state.dispose();
    _kick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: _calm ? Duration.zero : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: GlassPillButton(
          tone: GlassTone.media,
          height: widget.height,
          label: widget.label,
          semanticLabel: widget.semanticLabel,
          onTap: widget.onTap,
          // Only the glyph moves; it repaints itself off the controllers.
          glyph: RepaintBoundary(
            child: CustomPaint(
              size: const Size(19, 17),
              painter: _AutoAdvanceGlyphPainter(
                ink: MediaGlass.ink,
                state: _state,
                kick: _kick,
              ),
            ),
          ),
        ),
      );
}

/// Two line chevrons, ››, when on: carry on into the next note. Off, the
/// front one straightens into a bar, ›|: this note, then stop.
class _AutoAdvanceGlyphPainter extends CustomPainter {
  _AutoAdvanceGlyphPainter({
    required this.ink,
    required this.state,
    required this.kick,
  }) : super(repaint: Listenable.merge([state, kick]));

  final Color ink;
  final Animation<double> state;
  final Animation<double> kick;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final on = state.value;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      // Matched to the semibold label beside it, or it reads as punctuation.
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Forward and back once, easing out of the push.
    final k = kick.value;
    final push = k == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(k));
    for (var i = 0; i < 2; i++) {
      // The front chevron's point folds flat into the bar, a little further
      // forward and a little taller than the chevron it was.
      final fold = i == 1 ? on : 1.0;
      final x = w * (i == 0 ? 0.16 : 0.70 - 0.18 * on) +
          push * w * (0.10 + 0.06 * i);
      final rise = h * (0.2 - 0.04 * (1 - fold));
      stroke.color = ink;
      canvas.drawPath(
        Path()
          ..moveTo(x, rise)
          ..lineTo(x + w * 0.3 * fold, h * 0.5)
          ..lineTo(x, h - rise),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_AutoAdvanceGlyphPainter old) => old.ink != ink;
}

/// The playback ring drawn just inside the circle's edge.
class _NoteRingPainter extends CustomPainter {
  const _NoteRingPainter({
    required this.progress,
    required this.track,
    required this.ink,
    this.stroke = 3,
    this.knob = false,
  });

  final double progress;
  final Color track;
  final Color ink;
  final double stroke;

  /// A thumb at the head of the arc, while a finger is scrubbing — the ring
  /// becomes the timeline and needs the same handle a slider has.
  final bool knob;

  @override
  void paint(Canvas canvas, Size size) {
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
    if (progress > 0) {
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
    if (!knob) return;
    final angle = -math.pi / 2 + math.pi * 2 * progress;
    final r = circle.width / 2;
    final at = circle.center + Offset(math.cos(angle), math.sin(angle)) * r;
    final knobRadius = stroke * 1.9;
    canvas.drawCircle(
      at,
      knobRadius + 1,
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(at, knobRadius, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_NoteRingPainter old) =>
      old.progress != progress ||
      old.ink != ink ||
      old.track != track ||
      old.stroke != stroke ||
      old.knob != knob;
}

/// A playing video note, lifted out of the transcript to the middle of the
/// screen.
///
/// The circle flies from its bubble and back (a hand-rolled flight rather
/// than a `Hero`, because the destination is computed from the screen and the
/// source is re-measured every frame of the return). Under it: close, pause,
/// and the speed pill; above it, top right, the autoplay toggle. On it: a tap
/// pauses, and a drag around it scrubs — see [VideoNoteScrubRate] for how
/// sliding away from the circle slows the scrub down for fine positioning.
///
/// With autoplay on, a note that ends carries straight on into the next one
/// in [upNext], in place, at the same speed, while the chat scrolls behind
/// the dim to keep that note's bubble on screen. Closing flies home to
/// whichever note is showing, and puts the speed back to 1×: the speed is a
/// setting for this sitting, not for every note from now on.
///
/// The backdrop is a plain dim, never a blur: a blur under a flight is a
/// BackdropFilter animating every frame, which is exactly what drops frames.
class VideoNoteFocus extends StatefulWidget {
  const VideoNoteFocus({
    super.key,
    required this.playback,
    required this.storageId,
    required this.animation,
    required this.rectFor,
    required this.fallbackTotal,
    required this.handoff,
    this.upNext = const [],
    this.open,
    this.initialSource,
    this.once = false,
  });

  /// The note that was tapped. Its bubble owns it — unless [handoff] says the
  /// bubble went away while this was open, in which case this does.
  final VideoNotePlayback playback;
  final String storageId;

  /// The route's animation: drives the flight, the dim and the controls.
  final Animation<double> animation;

  /// Where the bubble showing [storageId] is now, in global coordinates;
  /// null when it is not on screen.
  final Rect? Function(String storageId) rectFor;

  /// The recorded length, for the moment before the player reports its own.
  final Duration fallbackTotal;

  final VideoNoteHandoff handoff;

  /// What autoplay carries on into, oldest first.
  final List<VideoNoteRef> upNext;

  /// Opens one of [upNext]. Throws when it cannot, and that note is skipped.
  final Future<VideoNotePlayback> Function(VideoNoteRef note)? open;

  /// Where the bubble was when the tap landed, for the frames before
  /// [rectFor] can measure it again.
  final Rect? initialSource;

  /// A play-once note ([ViewOnceVideoNote]): one watch, start to finish.
  ///
  /// No scrub (a drag round the ring is a way back), no replay (the end
  /// closes, and a tap on a finished note closes rather than rewinding), no
  /// autoplay toggle. It holds a [CaptureProtection] scope and wears the
  /// capture shield exactly as `ViewOnceViewer` does, and leaving the app
  /// closes it, for the same reason the photo closes.
  ///
  /// It does not fly home, either. Closed, the circle burns: it turns to
  /// dust ([DustDissolve]) on its way back down to the bubble, the dust left
  /// hanging where it let go, and the bubble underneath is already the
  /// played one — Telegram's disintegration. Reduced motion, and leaving the
  /// app, skip the burn for the ordinary flight home: a burn takes a second,
  /// and the face must not still be on screen when the app switcher takes
  /// its snapshot.
  final bool once;

  static TransitionRoute<void> route(
    BuildContext context, {
    required VideoNotePlayback playback,
    required String storageId,
    required Rect? Function(String storageId) rectFor,
    required Duration fallbackTotal,
    required VideoNoteHandoff handoff,
    List<VideoNoteRef> upNext = const [],
    Future<VideoNotePlayback> Function(VideoNoteRef note)? open,
    Rect? initialSource,
    bool once = false,
  }) {
    final motion = MotionScope.of(context);
    return _VideoNoteFocusRoute(
      transitionDuration: motion.d(const Duration(milliseconds: 360)),
      reverseTransitionDuration: motion.d(const Duration(milliseconds: 300)),
      builder: (animation) => VideoNoteFocus(
        playback: playback,
        storageId: storageId,
        animation: animation,
        rectFor: rectFor,
        fallbackTotal: fallbackTotal,
        handoff: handoff,
        upNext: upNext,
        open: open,
        initialSource: initialSource,
        once: once,
      ),
    );
  }

  @override
  State<VideoNoteFocus> createState() => _VideoNoteFocusState();
}

/// Who releases the tapped note's player. The bubble does, normally; but the
/// focus can outlive it (autoplay scrolls the chat, and the row the note sat
/// in gets recycled), and then the bubble marks it [orphaned] and leaves the
/// player to the focus rather than pulling it out from under the picture.
class VideoNoteHandoff {
  bool orphaned = false;

  /// A play-once focus has begun turning its circle to dust: the watch is
  /// over from this moment, and the bubble can show itself played under the
  /// dust rather than wait out the burn as a gap.
  VoidCallback? onBurn;
}

/// A popup, not a page route, on purpose: `MaterialApp`'s HeroController
/// holds every freshly pushed `PageRoute` offstage for its first frame to
/// measure heroes, and with the bubble already hidden that frame is a blink
/// where the note is nowhere. It also has no barrier: the page draws its own
/// dim, and its own tap-to-close.
class _VideoNoteFocusRoute extends PopupRoute<void> {
  _VideoNoteFocusRoute({
    required this.transitionDuration,
    required this.reverseTransitionDuration,
    required this.builder,
  });

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  final Widget Function(Animation<double> animation) builder;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      builder(animation);
}

class _VideoNoteFocusState extends State<VideoNoteFocus>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _controlsGap = 28.0;
  static const _controlsHeight = 52.0;
  static const _toggleGap = 18.0;
  static const _toggleHeight = 40.0;

  /// Decelerates into both ends: out of the chat into the middle, and back
  /// down into the bubble (the reverse curve runs t from 1 to 0).
  late final CurvedAnimation _flight = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The note on screen: the tapped one, or whichever autoplay reached.
  late VideoNotePlayback _playback = widget.playback;
  late String _storageId = widget.storageId;
  late Duration _fallbackTotal = widget.fallbackTotal;

  /// Players this focus opened itself, released when it closes.
  final List<VideoNotePlayback> _opened = [];
  int _nextIndex = 0;
  bool _advancing = false;

  /// For this sitting only — see the class doc.
  double _speed = VideoNoteSpeed.steps.first;

  /// The last place the bubble was seen, for a return flight whose bubble has
  /// since scrolled away.
  late Rect? _lastSource = widget.initialSource;

  bool _closing = false;

  /// A play-once close: the circle is turning to dust (see [VideoNoteFocus.once]).
  bool _burning = false;

  /// Drives the burn's flight home and the dim lifting, in step with the
  /// dust. The route's own animation stays at 1 throughout: the route is
  /// removed, not popped, when the dust has settled.
  late final AnimationController _burn = AnimationController(
    vsync: this,
    duration: DustDissolve.defaultDuration,
  );

  /// Set once this playthrough has actually played, so reaching the end
  /// closes or advances only when the note ran out — not when a paused scrub
  /// was dragged to the end and let go.
  bool _sawPlaying = false;

  bool _scrubbing = false;
  Duration _scrubAt = Duration.zero;
  VideoNoteScrubRate _rate = VideoNoteScrubRate.full;
  double? _lastAngle;
  int _lastSecond = 0;
  bool _resumeAfterScrub = false;

  /// Seeks are serialised and coalesced: a drag produces a position per
  /// pointer event, the player can take one at a time, and only the newest
  /// matters. Without this a fast spin queues hundreds of seeks and the
  /// picture trails the finger by seconds.
  Duration? _pendingSeek;
  Future<void>? _seekLoop;

  /// The ring's position, advanced every frame between the player's reports.
  ///
  /// `video_player` reports position every 100ms, which is six frames: drawn
  /// raw, the ring moves in visible steps, and at 2× each step is twice as
  /// long. So the last report is extrapolated at the playback speed until the
  /// next one arrives — never more than [_maxCoast] past it, so a stalled
  /// stream does not run the ring on ahead of a frozen picture.
  final ValueNotifier<Duration> _shown = ValueNotifier(Duration.zero);
  late final Ticker _ticker = createTicker(_onFrame);
  Duration _frameClock = Duration.zero;
  Duration _reported = Duration.zero;
  Duration _reportedAt = Duration.zero;
  static const _maxCoast = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    // `play()` went out just before this route was pushed, so its own change
    // notification has already gone by.
    _sawPlaying = _playback.isPlaying;
    _reported = _playback.position;
    _shown.value = _reported;
    _playback.addListener(_onPlayback);
    widget.animation.addStatusListener(_onRouteStatus);
    _syncTicker();
    if (widget.once) {
      WidgetsBinding.instance.addObserver(this);
      CaptureProtection.instance.pushScope();
      CaptureProtection.instance.ensureListening();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.once || state == AppLifecycleState.resumed) return;
    // Mid-burn, the dust goes at once: no face in the app switcher.
    if (_burning) return _burnt();
    _close(burn: false);
  }

  /// Frames only while the note is actually moving: paused, ended or held
  /// under a scrub, the reported position is already the truth.
  void _syncTicker() {
    final p = _playback;
    final moving = p.isPlaying && !p.isCompleted;
    if (moving && !_ticker.isActive) {
      _reportedAt = Duration.zero;
      _frameClock = Duration.zero;
      _ticker.start();
    } else if (!moving && _ticker.isActive) {
      _ticker.stop();
      _shown.value = p.isCompleted ? _total : p.position;
    }
  }

  @override
  void dispose() {
    if (widget.once) {
      CaptureProtection.instance.popScope();
      WidgetsBinding.instance.removeObserver(this);
    }
    widget.animation.removeStatusListener(_onRouteStatus);
    _playback.removeListener(_onPlayback);
    _ticker.dispose();
    _burn.dispose();
    _shown.dispose();
    _flight.dispose();
    // Normally cleared when the flight home lands (see [_onRouteStatus]); this
    // is for a route removed with no flight at all, which would otherwise
    // leave that note's bubble a permanent gap. After the frame: bubbles
    // cannot rebuild while this tree is being torn down.
    final shown = _storageId;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_VideoNoteStage.showing.value == shown) {
        _VideoNoteStage.showing.value = null;
      }
    });
    // Released after this frame, once nothing builds their pictures.
    final release = [
      ..._opened,
      if (widget.handoff.orphaned) widget.playback,
    ];
    if (release.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final p in release) {
          p.dispose();
        }
      });
    }
    super.dispose();
  }

  void _onRouteStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.reverse:
        // However the close was asked for — a tap, Esc, back — the voice stops
        // with it, and the tapped note goes home at 1× for next time.
        unawaited(_playback.pause());
        unawaited(widget.playback.setSpeed(VideoNoteSpeed.steps.first));
      case AnimationStatus.dismissed:
        // Landed: the bubble under the circle can draw itself again. Here and
        // not in dispose, where the bubbles could not rebuild.
        if (_VideoNoteStage.showing.value == _storageId) {
          _VideoNoteStage.showing.value = null;
        }
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        break;
    }
  }

  Duration get _total {
    final d = _playback.duration;
    return d > Duration.zero ? d : _fallbackTotal;
  }

  bool get _hasNext => widget.open != null && _nextIndex < widget.upNext.length;

  void _onFrame(Duration elapsed) {
    _frameClock = elapsed;
    final p = _playback;
    final total = _total;
    Duration at;
    if (p.isCompleted) {
      at = total;
    } else if (!p.isPlaying) {
      at = p.position;
    } else {
      var coast = elapsed - _reportedAt;
      if (coast > _maxCoast) coast = _maxCoast;
      at = _reported + coast * _speed;
      // A report that lands a hair behind the estimate would pull the ring
      // backwards for a frame. Small regressions are noise; a seek is not.
      final back = _shown.value - at;
      if (back > Duration.zero && back < const Duration(milliseconds: 150)) {
        at = _shown.value;
      }
    }
    if (total > Duration.zero && at > total) at = total;
    _shown.value = at;
  }

  void _onPlayback() {
    final p = _playback;
    if (p.position != _reported) {
      _reported = p.position;
      _reportedAt = _frameClock;
    }
    _syncTicker();
    if (!_ticker.isActive && !_scrubbing && _seekLoop == null) {
      _shown.value = p.isCompleted ? _total : p.position;
    }
    if (p.isPlaying && !p.isCompleted) _sawPlaying = true;
    if (p.isCompleted && _sawPlaying && !_scrubbing && _seekLoop == null) {
      _sawPlaying = false;
      // A beat on the last frame before moving on, so the end reads as an end
      // and not as the note being snatched away.
      final ended = p;
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted || _closing || _scrubbing) return;
        if (!identical(_playback, ended) || !ended.isCompleted) return;
        if (SettingsStore.instance.videoNoteAutoAdvance && _hasNext) {
          unawaited(_advance());
        } else {
          _close();
        }
      });
    }
  }

  /// Carries on into the next note that will open, skipping any that will
  /// not; closes when the run is out.
  Future<void> _advance() async {
    if (_advancing) return;
    final open = widget.open;
    if (open == null) return _close();
    setState(() => _advancing = true);
    while (_nextIndex < widget.upNext.length) {
      final note = widget.upNext[_nextIndex++];
      final VideoNotePlayback next;
      try {
        next = await open(note);
      } catch (e) {
        debugPrint('VideoNoteFocus: skipping ${note.storageId}: $e');
        continue;
      }
      if (!mounted || _closing) {
        next.dispose();
        return;
      }
      await next.setSpeed(_speed);
      if (!mounted || _closing) {
        next.dispose();
        return;
      }
      _switchTo(next, note);
      unawaited(next.play());
      return;
    }
    if (mounted) {
      setState(() => _advancing = false);
      _close();
    }
  }

  void _switchTo(VideoNotePlayback next, VideoNoteRef note) {
    final prev = _playback;
    prev.removeListener(_onPlayback);
    // The tapped note stays its bubble's unless the bubble is gone; anything
    // this focus opened is finished with. Released after the frame that stops
    // drawing it.
    final releasePrev = !identical(prev, widget.playback)
        ? _opened.remove(prev)
        : widget.handoff.orphaned;
    if (releasePrev) {
      SchedulerBinding.instance.addPostFrameCallback((_) => prev.dispose());
    }
    _opened.add(next);
    next.addListener(_onPlayback);
    _playback = next;
    _syncTicker();
    _storageId = note.storageId;
    final ms = note.durationMs;
    _fallbackTotal = ms == null ? Duration.zero : Duration(milliseconds: ms);
    _reported = Duration.zero;
    _reportedAt = _frameClock;
    _shown.value = Duration.zero;
    _sawPlaying = true;
    // The circle flies home to this note now, wherever its bubble turns out
    // to be — not to the one that was tapped.
    _lastSource = null;
    _VideoNoteStage.showing.value = note.storageId;
    note.reveal?.call();
    setState(() => _advancing = false);
  }

  void _close({bool burn = true}) {
    if (_closing || !mounted) return;
    _closing = true;
    if (burn &&
        widget.once &&
        widget.animation.status == AnimationStatus.completed &&
        !MediaQuery.disableAnimationsOf(context)) {
      _startBurn();
      return;
    }
    Navigator.of(context).pop();
  }

  /// The watch is over: the circle stops where it is and starts to burn.
  void _startBurn() {
    unawaited(_playback.pause());
    setState(() => _burning = true);
    unawaited(_burn.forward());
    // The bubble draws itself again — played, under the dust — now rather
    // than when the route goes.
    widget.handoff.onBurn?.call();
    if (_VideoNoteStage.showing.value == _storageId) {
      _VideoNoteStage.showing.value = null;
    }
  }

  /// The dust has settled. Removed rather than popped: there is nothing left
  /// to fly home.
  void _burnt() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  void _togglePlay() {
    final p = _playback;
    HapticFeedback.selectionClick();
    if (p.isCompleted) {
      // Played once means played: the end is a close, never a rewind.
      if (widget.once) return _close();
      unawaited(p.seekToStart().then((_) => p.play()));
      return;
    }
    if (p.isPlaying) {
      _sawPlaying = false;
      unawaited(p.pause());
    } else {
      unawaited(p.play());
    }
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    setState(() => _speed = VideoNoteSpeed.after(_speed));
    unawaited(_playback.setSpeed(_speed));
  }

  void _toggleAutoAdvance() {
    HapticFeedback.selectionClick();
    final store = SettingsStore.instance;
    unawaited(store.setVideoNoteAutoAdvance(!store.videoNoteAutoAdvance));
    setState(() {});
  }

  void _scrubStart(Offset local, double radius) {
    final p = _playback;
    final total = _total;
    if (total <= Duration.zero || _advancing) return;
    _resumeAfterScrub = p.isPlaying && !p.isCompleted;
    _sawPlaying = false;
    if (_resumeAfterScrub) unawaited(p.pause());
    final at = p.isCompleted ? total : _shown.value;
    _scrubAt = at > total ? total : at;
    _lastSecond = _scrubAt.inSeconds;
    _lastAngle = null;
    _rate = VideoNoteScrubRate.full;
    HapticFeedback.lightImpact();
    setState(() => _scrubbing = true);
    _scrubTrack(local, radius);
  }

  void _scrubTrack(Offset local, double radius) {
    if (!_scrubbing) return;
    final v = local - Offset(radius, radius);
    final distance = v.distance;
    final rate = videoNoteScrubRateFor(distance, radius, current: _rate);
    if (rate != _rate) {
      HapticFeedback.lightImpact();
      setState(() => _rate = rate);
    }
    // Near the centre the angle swings wildly for a tiny movement; a finger
    // crossing the middle would otherwise throw the position around.
    if (distance < radius * 0.22) {
      _lastAngle = null;
      return;
    }
    final angle = math.atan2(v.dy, v.dx);
    final last = _lastAngle;
    _lastAngle = angle;
    if (last == null) return;
    final next = videoNoteScrubBy(
      from: _scrubAt,
      turn: videoNoteAngleDelta(last, angle),
      rate: _rate,
      total: _total,
    );
    if (next == _scrubAt) return;
    if (next.inSeconds != _lastSecond) {
      _lastSecond = next.inSeconds;
      HapticFeedback.selectionClick();
    }
    setState(() => _scrubAt = next);
    _pendingSeek = next;
    _seekLoop ??= _runSeeks();
  }

  Future<void> _runSeeks() async {
    final p = _playback;
    try {
      while (_pendingSeek != null) {
        final to = _pendingSeek!;
        _pendingSeek = null;
        try {
          await p.seekTo(to);
        } catch (e) {
          debugPrint('VideoNoteFocus.seekTo($to): $e');
        }
      }
    } finally {
      _seekLoop = null;
      // The ring picks up from where the finger left it, not from the last
      // report before the scrub.
      _reported = p.position;
      _reportedAt = _frameClock;
      _shown.value = p.position;
      if (mounted) setState(() {});
    }
  }

  Future<void> _scrubEnd() async {
    if (!_scrubbing) return;
    setState(() => _scrubbing = false);
    // The picture lands where the finger let go before playback resumes, or
    // the first frames played would be from a seek that was already stale.
    await (_seekLoop ?? Future<void>.value());
    if (!mounted || _closing || !_resumeAfterScrub) return;
    // Let go at the very end: nothing left to resume, and `play()` from the
    // end would quietly restart the note from the top.
    if (_total - _scrubAt < const Duration(milliseconds: 150)) return;
    unawaited(_playback.play());
  }

  @override
  Widget build(BuildContext context) {
    // Over the whole app, outside any Scaffold: without this every Text in
    // here falls back to Flutter's debug style.
    return Material(
      type: MaterialType.transparency,
      // Back and Esc on a play-once note burn it like any other close; the
      // route is removed by the burn, never popped out from under it.
      child: PopScope(
        canPop: !widget.once,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.animation, _playback, _burn]),
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) => _layout(context, box.biggest),
          ),
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, Size screen) {
    final l10n = AppLocalizations.of(context);
    final pad = MediaQuery.paddingOf(context);
    // Burning, the burn's own clock stands in for the route's: the dim
    // lifts over its first half, and the circle sinks home through the
    // middle of it, so the last of it lets go over the bubble.
    final burn = _burn.value;
    final fade = widget.animation.value *
        (1 - const Interval(0, 0.55, curve: Curves.easeOut).transform(burn));
    final t = _burning
        ? 1 -
            const Interval(0.1, 0.8, curve: Curves.easeInOutCubic)
                .transform(burn)
        : _flight.value;

    final usableHeight = screen.height - pad.vertical;
    final diameter = math.min(
      math.min(screen.width - 40, usableHeight * 0.62),
      460.0,
    );
    // The circle sits in the middle of everything around it: the controls
    // below and, when there is a chat to carry on into, the toggle above. A
    // play-once note has no controls row, only its Close at the foot of the
    // screen.
    final below = widget.once ? 0.0 : _controlsGap + _controlsHeight;
    // The play-once badge takes the toggle's place above the circle.
    final above = widget.open != null || widget.once
        ? _toggleGap + _toggleHeight
        : 0.0;
    final target = Rect.fromCenter(
      center: Offset(
        screen.width / 2,
        pad.top + usableHeight / 2 - (below - above) / 2,
      ),
      width: diameter,
      height: diameter,
    );

    final source = widget.rectFor(_storageId) ?? _lastSource;
    if (source != null) _lastSource = source;
    // No bubble to fly from (it scrolled away): grow and fade in place.
    final circle = source == null
        ? Rect.fromCenter(
            center: target.center,
            width: diameter * (0.7 + 0.3 * t),
            height: diameter * (0.7 + 0.3 * t),
          )
        : Rect.lerp(source, target, t)!;

    final settled =
        widget.animation.status == AnimationStatus.completed && !_burning;
    final chromeOpacity = ((fade - 0.5) / 0.5).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            button: true,
            label: l10n.photoChromeCloseSemanticLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.72 * fade),
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: circle,
          child: Opacity(
            opacity: source == null ? fade : 1,
            child: widget.once
                ? DustDissolve(
                    active: _burning,
                    shape: const CircleBorder(),
                    seed: _storageId.hashCode,
                    onDone: _burnt,
                    child: _circle(context, circle.width),
                  )
                : _circle(context, circle.width),
          ),
        ),
        // Telegram's: one capsule at the foot of the screen, and nothing else
        // to press.
        if (widget.once)
          Positioned(
            left: 16,
            right: 16,
            bottom: pad.bottom + 24,
            child: Center(
              child: IgnorePointer(
                ignoring: !settled,
                child: Opacity(
                  opacity: chromeOpacity,
                  child: GlassStill(
                    still: true,
                    child: GlassPillButton(
                      tone: GlassTone.media,
                      label: l10n.photoChromeCloseSemanticLabel,
                      onTap: _close,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!widget.once)
          Positioned(
            left: 0,
            right: 0,
            top: target.bottom + _controlsGap,
            height: _controlsHeight,
            child: IgnorePointer(
              ignoring: !settled,
              child: Opacity(
                opacity: chromeOpacity,
                // The controls fade with the flight; a fading blur is a
                // BackdropFilter re-rasterising every frame.
                child: GlassStill(still: true, child: _controls(l10n)),
              ),
            ),
          ),
        // Above the circle, as the controls are below it. The scrub hint takes
        // its place while a finger is on the ring.
        if (widget.open != null && !_scrubbing)
          Positioned(
            left: 16,
            right: 16,
            top: target.top - _toggleGap - _toggleHeight,
            height: _toggleHeight,
            child: Center(
              child: IgnorePointer(
                ignoring: !settled,
                child: Opacity(
                  opacity: chromeOpacity,
                  child:
                      GlassStill(still: true, child: _autoAdvanceToggle(l10n)),
                ),
              ),
            ),
          ),
        if (widget.once)
          Positioned(
            left: 16,
            right: 16,
            top: target.top - _toggleGap - _toggleHeight,
            height: _toggleHeight,
            child: Center(
              child: IgnorePointer(
                child: Opacity(
                  opacity: chromeOpacity,
                  child: GlassStill(
                    still: true,
                    child: ViewOnceBadge(label: l10n.messageBubblePlayOnceLabel),
                  ),
                ),
              ),
            ),
          ),
        // Last, so appearing mid-drag never shifts the circle's element and
        // drops the gesture that is driving it.
        if (_scrubbing)
          Positioned(
            left: 16,
            right: 16,
            bottom: screen.height - target.top + 18,
            child: Center(
              child: GlassStill(
                still: true,
                child: MediaNoteCapsule(
                  text: switch (_rate) {
                    VideoNoteScrubRate.full => l10n.videoNoteScrubHint,
                    VideoNoteScrubRate.half => l10n.videoNoteScrubHalf,
                    VideoNoteScrubRate.fine => l10n.videoNoteScrubFine,
                  },
                ),
              ),
            ),
          ),
        // Over everything, the photo viewer's shield: a recording or a mirror
        // sees the shield, not the face.
        if (widget.once) const CaptureShield(),
      ],
    );
  }

  Widget _circle(BuildContext context, double diameter) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final p = _playback;
    final total = _total;
    final holding = _scrubbing || _seekLoop != null;
    final playing = p.isPlaying && !p.isCompleted && !holding;
    final radius = diameter / 2;
    final settled =
        widget.animation.status == AnimationStatus.completed && !_burning;
    // The dim and the play disc over a paused note. Not over a play-once
    // note that has ended or is burning: what turns to dust is the last
    // frame, not a play button that was never going to be pressed.
    final resting = !playing &&
        !holding &&
        !_burning &&
        !(widget.once && p.isCompleted);

    return Semantics(
      button: true,
      label: playing
          ? l10n.videoNoteMessagePauseLabel
          : l10n.videoNoteMessagePlayLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: settled ? _togglePlay : null,
        // No scrub on a play-once note: a drag round the ring is a way back.
        onPanStart: settled && !widget.once
            ? (d) => _scrubStart(d.localPosition, radius)
            : null,
        onPanUpdate:
            widget.once ? null : (d) => _scrubTrack(d.localPosition, radius),
        onPanEnd: widget.once ? null : (_) => _scrubEnd(),
        onPanCancel: widget.once ? null : _scrubEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(child: p.view()),
            if (resting)
              const ClipOval(child: ColoredBox(color: Color(0x40000000))),
            // The ring and the countdown read the per-frame position, so the
            // rest of the circle does not rebuild sixty times a second.
            ValueListenableBuilder<Duration>(
              valueListenable: _shown,
              builder: (context, shown, _) {
                final display = videoNoteDisplayFor(
                  rawPlaying: playing,
                  completed: !holding && p.isCompleted,
                  position: holding ? _scrubAt : shown,
                  total: total,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _NoteRingPainter(
                          progress: display.progress,
                          track: Colors.white.withValues(alpha: 0.25),
                          ink: theme.accent,
                          stroke: holding ? 6 : 4,
                          knob: holding,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: diameter * 0.09,
                      child: Center(
                        child: MediaDurationBadge(duration: display.remaining),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_advancing)
              const Center(
                child: CupertinoActivityIndicator(
                  radius: 14,
                  color: Colors.white,
                ),
              )
            else if (resting)
              const Center(child: MediaPlayDisc(size: 64)),
          ],
        ),
      ),
    );
  }

  Widget _autoAdvanceToggle(AppLocalizations l10n) {
    final on = SettingsStore.instance.videoNoteAutoAdvance;
    return Semantics(
      toggled: on,
      child: _AutoAdvanceToggle(
        on: on,
        label: on
            ? l10n.videoNoteAutoAdvanceOn
            : l10n.videoNoteAutoAdvanceOff,
        semanticLabel: l10n.videoNoteAutoAdvanceSemanticLabel,
        height: _toggleHeight,
        onTap: _toggleAutoAdvance,
      ),
    );
  }

  Widget _controls(AppLocalizations l10n) {
    final p = _playback;
    final playing = p.isPlaying && !p.isCompleted;
    final speed = VideoNoteSpeed.label(_speed);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: GlassIconButton(
              tone: GlassTone.media,
              icon: CupertinoIcons.xmark,
              semanticLabel: l10n.photoChromeCloseSemanticLabel,
              onTap: _close,
            ),
          ),
        ),
        const SizedBox(width: 20),
        GlassIconButton(
          tone: GlassTone.media,
          size: _controlsHeight,
          iconSize: 22,
          icon: playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
          semanticLabel: playing
              ? l10n.videoNoteMessagePauseLabel
              : l10n.videoNoteMessagePlayLabel,
          onTap: _togglePlay,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: GlassPillButton(
              tone: GlassTone.media,
              label: speed,
              semanticLabel: l10n.videoNoteSpeedLabel(speed),
              onTap: _cycleSpeed,
            ),
          ),
        ),
      ],
    );
  }
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
    this.viewOnce = false,
    this.seedKey,
  });

  final AppTheme theme;
  final double diameter;
  final bool failed;

  /// A play-once send: [posterBytes] is the sixteen-pixel stand-in, and the
  /// circle wears the sealed face from its first frame (the stand-in blurred,
  /// the dust fading in), so the sent circle that replaces it is the same
  /// object carrying on, not a swap.
  final bool viewOnce;

  /// What seeds the face; the sent circle is handed the same (see
  /// [ViewOnceVideoNote.seedKey]).
  final String? seedKey;

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
    final key = seedKey;
    // Left for the sent circle, so it draws these very pixels at once.
    if (viewOnce && key != null && poster != null) {
      _MicroPosters.rememberKey(key, poster);
    }
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (viewOnce)
            _OnceFace(
              seed: (key ?? '').hashCode,
              tint: theme.accent,
              poster: poster,
              dust: true,
              ghost: false,
            )
          else ...[
            ClipOval(
              child: poster == null
                  ? ColoredBox(color: theme.surfaceSunken)
                  : Image.memory(poster, fit: BoxFit.cover),
            ),
            const ClipOval(child: ColoredBox(color: Color(0x59000000))),
          ],
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
                      icon: CupertinoIcons.arrow_clockwise,
                      label: l10n.videoNoteMessageRetryLabel,
                      onTap: () => onRetry!(),
                    ),
                  if (onRetry != null && onDiscard != null)
                    const SizedBox(width: 10),
                  if (onDiscard != null)
                    _circleAction(
                      icon: CupertinoIcons.xmark,
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

  /// Retry / discard over a failed upload: the shared 40pt media glass
  /// button (it was a 36pt GestureDetector disc with no press and no focus).
  Widget _circleAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GlassIconButton(
      tone: GlassTone.media,
      icon: icon,
      semanticLabel: label,
      onTap: onTap,
    );
  }
}
