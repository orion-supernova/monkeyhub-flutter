import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../media/video_poster.dart';
import '../screens/voice_recorder_screen.dart' show voiceNoteContentType;
import 'capture_permissions.dart';

/// The MIME a video note is stored under.
///
/// `video/mp4` on both platforms: AVFoundation writes a `.mov`-extensioned
/// ISO-BMFF file whose brand is `qt`, and MediaRecorder writes a real MP4. The
/// two are the same family and every player this app uses reads both, but
/// Convex fixes contentType at upload time and cannot be patched afterwards —
/// so labelling a QuickTime-branded file `video/quicktime` would strand it on
/// browsers that only accept `video/mp4`, and this direction fails for nobody.
/// See [voiceNoteContentType] for the same lesson learned the hard way on audio.
const videoNoteContentType = 'video/mp4';

/// Why a capture ended without bytes.
enum CaptureFailureKind {
  /// The user has not granted, or can no longer grant, the device.
  permission,

  /// No hardware, no plugin, or a browser. Nothing to retry.
  unavailable,

  /// A phone call, another app taking the camera, the OS suspending us, a
  /// revoked grant mid-record. Retrying is reasonable.
  interrupted,

  /// The recorder produced nothing usable — a zero-byte file is what a full
  /// disk looks like from here.
  storage,

  /// Released before [kMinRecordingDuration]. Silent by design: a mis-tap
  /// should not produce an error message.
  tooShort,

  unknown,
}

/// A capture that failed. Carries the grant when the reason was a permission,
/// so the caller can tell "ask again" from "go to Settings" from "you can't".
class CaptureFailure implements Exception {
  const CaptureFailure(this.kind, {this.grant, this.device});
  final CaptureFailureKind kind;
  final CaptureGrant? grant;
  final CaptureDevice? device;

  @override
  String toString() => 'CaptureFailure($kind, grant: $grant, device: $device)';
}

/// A finished recording, in the shape the send path wants.
///
/// Bytes, not a path, for the same reason [UploadService] takes bytes: the
/// upload is bytes-only, and by the time this exists the temp file has already
/// been deleted. Holding a path would mean a second thing that can be missing
/// by the time anyone reads it.
class CaptureOutcome {
  const CaptureOutcome({
    required this.bytes,
    required this.contentType,
    required this.duration,
    this.posterBytes,
    this.viewOnce = false,
  });

  final Uint8List bytes;
  final String contentType;
  final Duration duration;

  /// Sent to be played once: the recipient hears or sees it a single time,
  /// then it burns, exactly as a view-once photo does. Chosen in the
  /// recording strip, carried here so the send path needs no second channel.
  final bool viewOnce;

  CaptureOutcome withViewOnce(bool value) => CaptureOutcome(
        bytes: bytes,
        contentType: contentType,
        duration: duration,
        posterBytes: posterBytes,
        viewOnce: value,
      );

  /// A JPEG still for a video note, so the circular bubble has something to
  /// draw before anyone taps it. Null for audio and on any platform
  /// [VideoPoster] cannot serve.
  final Uint8List? posterBytes;
}

/// One stretch of a paused-and-resumed recording, still on disk.
///
/// Pause is not a pause. Neither `record` nor `camera` can suspend a file
/// mid-write on every platform this app ships to, so "pause" finishes the file
/// being written and "resume" starts a new one; the send joins them back up in
/// `composeCapture`. This is the hand-over between those two moments.
///
/// **Whoever holds a segment owns its file.** [CaptureRecorder.stopSegment]
/// gives it up and never looks at the path again, so a segment that is
/// dropped without going through `composeCapture` (which deletes it) or
/// `discardSegments` is a leaked file until the next launch's sweep.
@immutable
class CaptureSegment {
  const CaptureSegment({
    required this.path,
    required this.duration,
    required this.contentType,
    this.levels = const [],
  });

  /// A real filesystem path. Inside [CaptureTempFiles]' folder for every
  /// segment this file produces, so the sweeper covers it if the app dies
  /// before it is sent.
  final String path;

  /// How long the segment ran, by the wall clock between start and stop.
  /// Within a frame or two of the file's own duration — close enough to lay
  /// out a timeline with, not close enough to cut on, which is why
  /// `composeCapture` answers the true duration of what it produced.
  final Duration duration;

  final String contentType;

  /// 0..1 loudness samples observed while this segment recorded, one per
  /// meter tick (120 ms). Empty for video. Concatenated across segments by
  /// `waveform`, which is what the review strip draws.
  final List<double> levels;

  @override
  String toString() => 'CaptureSegment($path, $duration)';
}

/// Where in-progress captures live, and the sweeper that stops them piling up.
///
/// Every recording writes to its own file here and deletes it on the way out —
/// on send, on cancel, and on failure. The sweeper exists for the fourth case
/// nobody can code around: the process dying between `start` and `stop`, which
/// leaves a file with no owner and no code path that will ever look at it
/// again. Without it, a user who force-quits mid-record leaks a video per
/// crash into a directory the OS only clears under disk pressure.
class CaptureTempFiles {
  CaptureTempFiles._();

  static const _folder = 'mh_capture';

  /// Anything older than this at sweep time is from a previous life. Generous
  /// enough that it can never race a live recording — the longest capture this
  /// app allows is five minutes.
  static const _staleAfter = Duration(hours: 1);

  static Future<Directory>? _dir;
  static bool _swept = false;

  static Future<Directory> _directory() {
    return _dir ??= () async {
      final base = await getTemporaryDirectory();
      final dir = Directory('${base.path}/$_folder');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }();
  }

  /// A fresh path to record into. The file itself is created by the recorder,
  /// not here — `record` and `camera` both want to own the handle.
  static Future<String> newPath(String extension) async {
    final dir = await _directory();
    unawaited(sweep());
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return '${dir.path}/cap_$stamp.$extension';
  }

  /// Best-effort delete. Never throws: a cleanup that can fail the operation it
  /// is cleaning up after is worse than a leaked file.
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('CaptureTempFiles.delete: $e');
    }
  }

  /// Removes orphans left by a previous run. Once per process — the only way
  /// new orphans appear is a crash, and a crash starts a new process.
  static Future<void> sweep() async {
    if (_swept) return;
    _swept = true;
    try {
      final dir = await _directory();
      final now = DateTime.now();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          final age = now.difference((await entity.stat()).modified);
          if (age > _staleAfter) await entity.delete();
        } catch (_) {
          // One unreadable entry must not abandon the rest of the sweep.
        }
      }
    } catch (e) {
      debugPrint('CaptureTempFiles.sweep: $e');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _dir = null;
    _swept = false;
  }
}

/// One recording, from start to bytes.
///
/// An interface rather than a concrete class so the widget above it can be
/// exercised without a microphone or a camera — neither of which exists in a
/// widget test, and neither of which this agent can verify at all. The two real
/// implementations are [VoiceCaptureRecorder] and [VideoNoteCaptureRecorder].
abstract class CaptureRecorder {
  /// Fires when the platform stops the recording without being asked —
  /// an incoming call seizing the microphone, another app taking the lens, a
  /// grant revoked from Settings while the app was in the background, a thermal
  /// shutdown. The holder aborts on it, which deletes the partial file.
  ///
  /// On the interface rather than on one implementation because both devices
  /// can be taken away and the UI's answer is identical for both.
  abstract VoidCallback? onSessionLost;

  /// Opens the device and begins writing. Throws [CaptureFailure] if it cannot.
  Future<void> start();

  /// Closes the stream and returns the bytes, or throws [CaptureFailure].
  Future<CaptureOutcome> stop();

  /// Pause: finishes the file being written and hands it over *without*
  /// reading or deleting it. The caller owns the file from here (see
  /// [CaptureSegment]). Throws [CaptureFailure] when nothing was recording or
  /// the file came out empty — in which case it is already deleted.
  ///
  /// The device stays open: for a video note the preview keeps running while
  /// paused, and [start] afterwards begins a fresh segment file. The
  /// single-take path is unchanged — [stop] is still what a recording that
  /// was never paused ends with.
  Future<CaptureSegment> stopSegment();

  /// Stops and throws the recording away, deleting its temp file. Never
  /// throws — cancel is the path failures fall back to.
  Future<void> cancel();

  /// Releases the device. Safe to call more than once.
  Future<void> dispose();

  /// 0..1 loudness for a live meter, where the device reports one. Null for
  /// video notes, whose meter is the picture.
  Stream<double>? get levels => null;
}

/// The slice of `record`'s [AudioRecorder] that [VoiceCaptureRecorder] uses.
///
/// A seam, and a load-bearing one: `AudioRecorder`'s *constructor* already
/// reaches for the platform channel, so a test that so much as builds one on a
/// VM host gets an unhandled `MissingPluginException` from inside a
/// `whenComplete` nobody can catch. With this, the cancel-deletes-its-temp-file
/// rule — the one thing about recording that is testable without a
/// microphone — actually has a test.
abstract class AudioRecorderPort {
  Future<bool> hasPermission();
  Future<void> start(RecordConfig config, {required String path});
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
  Stream<Amplitude> onAmplitudeChanged(Duration interval);
  Stream<RecordState> onStateChanged();
}

/// The real one.
class PluginAudioRecorder implements AudioRecorderPort {
  final _rec = AudioRecorder();

  @override
  Future<bool> hasPermission() async {
    try {
      return await _rec.hasPermission();
    } catch (e) {
      debugPrint('PluginAudioRecorder.hasPermission: $e');
      return false;
    }
  }

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    try {
      await _rec.start(config, path: path);
    } catch (e) {
      debugPrint('PluginAudioRecorder.start: $e');
      rethrow;
    }
  }

  @override
  Future<String?> stop() async {
    try {
      return await _rec.stop();
    } catch (e) {
      debugPrint('PluginAudioRecorder.stop: $e');
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _rec.cancel();
    } catch (e) {
      debugPrint('PluginAudioRecorder.cancel: $e');
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _rec.dispose();
    } catch (e) {
      debugPrint('PluginAudioRecorder.dispose: $e');
    }
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      _rec.onAmplitudeChanged(interval);

  @override
  Stream<RecordState> onStateChanged() => _rec.onStateChanged();
}

/// A voice note, recorded with `record` into AAC-LC.
///
/// Exactly the encoder settings and container [VoiceRecorderScreen] has always
/// used, and deliberately so: `AudioFileCache`, the `audio/mp4` content type
/// and every voice note already in history all assume this shape, and a second
/// audio format in the same app would be a second set of playback bugs.
class VoiceCaptureRecorder implements CaptureRecorder {
  VoiceCaptureRecorder({AudioRecorderPort? recorder})
      : _rec = recorder ?? PluginAudioRecorder();

  final AudioRecorderPort _rec;
  String? _path;
  DateTime? _startedAt;
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<RecordState>? _stateSub;
  final _levels = StreamController<double>.broadcast();
  bool _disposed = false;

  /// Every meter sample of the segment being written, kept for the review
  /// strip's waveform. A 5-minute cap at one sample per 120 ms is 2,500
  /// doubles — not worth a ring buffer.
  final List<double> _segmentLevels = [];

  @override
  VoidCallback? onSessionLost;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> start() async {
    if (kIsWeb) {
      // `record_web` writes opus/webm, which the send path would label AAC and
      // every player downstream would refuse. Absent beats broken — the same
      // call the attachment sheet already makes for its voice tile.
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
    final grant = await CapturePermissions.request(CaptureDevice.microphone);
    if (grant != CaptureGrant.granted) {
      throw CaptureFailure(CaptureFailureKind.permission,
          grant: grant, device: CaptureDevice.microphone);
    }
    // iOS answers here rather than through the channel above — `hasPermission`
    // raises the system sheet and reports what the user said.
    //
    // Wrapped, because on a platform with no `record` implementation at all
    // (a desktop build without the plugin, a test host) this throws a
    // MissingPluginException rather than answering — which is "no recorder",
    // not "no permission", and must not be reported as a refusal the user can
    // fix in Settings.
    final bool granted;
    try {
      granted = await _rec.hasPermission();
    } catch (e) {
      debugPrint('VoiceCaptureRecorder.hasPermission: $e');
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
    if (!granted) {
      throw const CaptureFailure(CaptureFailureKind.permission,
          grant: CaptureGrant.deniedForever,
          device: CaptureDevice.microphone);
    }

    final path = await CaptureTempFiles.newPath('m4a');
    try {
      // Not "faststart" — see VoiceRecorderScreen for why that is fine here and
      // why remuxing to get it would be a mistake.
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 96000,
        ),
        path: path,
      );
    } catch (e) {
      await CaptureTempFiles.delete(path);
      debugPrint('VoiceCaptureRecorder.start: $e');
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
    _path = path;
    _startedAt = DateTime.now();
    _segmentLevels.clear();
    _ampSub = _rec
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((a) {
      if (_disposed || _levels.isClosed) return;
      // dBFS, typically -60..0. The same normalisation the full-screen
      // recorder's meter uses, so the two look like the same app.
      final level = ((a.current + 45) / 45).clamp(0.0, 1.0);
      _segmentLevels.add(level);
      _levels.add(level);
    }, onError: (Object e) => debugPrint('amplitude: $e'));
    // A `stop` we did not ask for is the platform taking the microphone away —
    // an incoming call is the ordinary case, and without this the timer would
    // keep counting up over a recorder that stopped writing seconds ago.
    // Guarded on [_path] because our own `stop()` clears it first, so the
    // stream event our own call produces is already indistinguishable from the
    // interruption by the time it arrives.
    _stateSub = _rec.onStateChanged().listen((s) {
      if (_disposed || s != RecordState.stop || _path == null) return;
      onSessionLost?.call();
    }, onError: (Object e) => debugPrint('record state: $e'));
  }

  @override
  Future<CaptureOutcome> stop() async {
    final started = _startedAt;
    await _ampSub?.cancel();
    _ampSub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    // Cleared before the stop, not after: the state stream reports our own stop
    // exactly as it reports an interruption, and a null [_path] is what tells
    // the listener above which of the two it is looking at.
    final ours = _path;
    _path = null;
    _startedAt = null;
    String? path;
    try {
      path = await _rec.stop();
    } catch (e) {
      debugPrint('VoiceCaptureRecorder.stop: $e');
    }
    path ??= ours;
    if (path == null) throw const CaptureFailure(CaptureFailureKind.interrupted);

    Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (e) {
      debugPrint('VoiceCaptureRecorder.read: $e');
      await CaptureTempFiles.delete(path);
      throw const CaptureFailure(CaptureFailureKind.storage);
    }
    // The file is gone before the caller ever sees the bytes — there is no
    // later moment where anyone still knows this path.
    await CaptureTempFiles.delete(path);
    if (bytes.isEmpty) {
      throw const CaptureFailure(CaptureFailureKind.storage);
    }
    return CaptureOutcome(
      bytes: bytes,
      contentType: voiceNoteContentType,
      duration: started == null
          ? Duration.zero
          : DateTime.now().difference(started),
    );
  }

  @override
  Future<CaptureSegment> stopSegment() async {
    final started = _startedAt;
    await _ampSub?.cancel();
    _ampSub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    // Cleared before the stop for the same reason [stop] clears it: our own
    // stop must not read as the platform taking the microphone away.
    final ours = _path;
    _path = null;
    _startedAt = null;
    final levels = List<double>.unmodifiable(_segmentLevels);
    _segmentLevels.clear();
    if (ours == null) {
      throw const CaptureFailure(CaptureFailureKind.interrupted);
    }
    String? path;
    try {
      path = await _rec.stop();
    } catch (e) {
      debugPrint('VoiceCaptureRecorder.stopSegment: $e');
    }
    path ??= ours;

    // Checked here rather than at compose time: an empty segment discovered
    // at send is a recording the user already thinks they have.
    var length = 0;
    try {
      length = await File(path).length();
    } catch (e) {
      debugPrint('VoiceCaptureRecorder.stopSegment length: $e');
    }
    if (length == 0) {
      await CaptureTempFiles.delete(path);
      if (path != ours) await CaptureTempFiles.delete(ours);
      throw const CaptureFailure(CaptureFailureKind.storage);
    }
    return CaptureSegment(
      path: path,
      duration:
          started == null ? Duration.zero : DateTime.now().difference(started),
      contentType: voiceNoteContentType,
      levels: levels,
    );
  }

  @override
  Future<void> cancel() async {
    await _ampSub?.cancel();
    _ampSub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    _segmentLevels.clear();
    final ours = _path;
    _path = null;
    _startedAt = null;
    try {
      // `cancel` stops and deletes on the plugin side; the explicit delete
      // below covers the platforms where it only stops.
      await _rec.cancel();
    } catch (e) {
      debugPrint('VoiceCaptureRecorder.cancel: $e');
    }
    await CaptureTempFiles.delete(ours);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    onSessionLost = null;
    await _ampSub?.cancel();
    await _stateSub?.cancel();
    await CaptureTempFiles.delete(_path);
    _path = null;
    await _levels.close();
    try {
      await _rec.dispose();
    } catch (e) {
      debugPrint('VoiceCaptureRecorder.dispose: $e');
    }
  }
}

/// A circular video note, recorded with `camera`.
///
/// Owns the [CameraController] rather than borrowing one, because the
/// controller's lifetime and the recording's are the same question: releasing
/// the session on a backgrounding, re-acquiring it on resume and noticing that
/// another app took the lens are all things the recording has to know about,
/// and splitting them across two objects is how a stranded camera happens.
///
/// The widget renders [controller] directly. Null whenever the session is not
/// held, which is exactly when there is nothing to draw.
///
/// **The video is not cropped to a circle.** The circle is the *bubble*, which
/// draws the frame with `BoxFit.cover` inside a `ClipOval`. Cropping the file
/// would mean a full transcode on the sender's phone for a shape every reader
/// already applies for free, and would leave the bytes unplayable anywhere the
/// crop was not known about.
class VideoNoteCaptureRecorder implements CaptureRecorder {
  VideoNoteCaptureRecorder({
    CameraLensDirection lens = CameraLensDirection.front,
    @visibleForTesting Future<List<CameraDescription>> Function()? cameras,
  })  : _lens = lens,
        _cameras = cameras ?? availableCameras;

  /// Opens on the front lens. A video note is a message *of you*, the same
  /// reasoning the composer's camera button already uses.
  CameraLensDirection _lens;

  /// The lens the session is on, or will open on. Changes on [flip], and in
  /// [warm] when the device has no lens facing the asked-for way.
  CameraLensDirection get lens => _lens;

  /// The lens is the user's own face. The UI's answer to a "flash" here is a
  /// white screen, which is why [hasTorch] is false on this side.
  bool get frontFacing => _lens == CameraLensDirection.front;

  final Future<List<CameraDescription>> Function() _cameras;

  /// What [warm] found, kept for [flip]. Empty until the first warm.
  List<CameraDescription> _available = const [];

  /// More than one way to face. False before the first [warm], which is when
  /// nobody has asked the OS yet.
  bool get canFlip =>
      _available.any((c) => c.lensDirection == CameraLensDirection.front) &&
      _available.any((c) => c.lensDirection != CameraLensDirection.front);

  bool _flipping = false;
  bool _torch = false;

  /// Set once the platform refuses a torch on this lens — the plugin has no
  /// "does this camera have a flash" query, so the first refusal is the
  /// answer. Cleared on flip: it belongs to the lens, not the device.
  bool _torchRefused = false;

  /// A torch is a back-camera thing. Optimistic until [setTorch] has been
  /// refused once (iPads and a few budget phones have no LED at all).
  bool get hasTorch =>
      _controller != null &&
      _lens == CameraLensDirection.back &&
      !_torchRefused;

  bool get torchOn => _torch;

  CameraController? _controller;
  CameraController? get controller => _controller;

  /// No meter. A video note's level indicator is the picture — a second,
  /// numeric one beside a live preview of the speaker's face would be noise.
  @override
  Stream<double>? get levels => null;

  String? _path;
  DateTime? _startedAt;
  bool _disposed = false;
  bool _recording = false;
  bool get isRecording => _recording;

  @override
  VoidCallback? onSessionLost;

  /// Brings the preview up without recording anything.
  ///
  /// Separate from [start] because the preview has to be live *before* the hold
  /// begins — a video note that showed nothing until the recording was already
  /// running would have the user framing a shot they cannot see. This is also
  /// what makes the camera lazy: nothing here runs until the button is actually
  /// switched to video-note mode.
  Future<void> warm() async {
    if (_disposed || _controller != null) return;
    if (kIsWeb) throw const CaptureFailure(CaptureFailureKind.unavailable);

    final grant = await CapturePermissions.request(CaptureDevice.camera);
    if (grant != CaptureGrant.granted) {
      throw CaptureFailure(CaptureFailureKind.permission,
          grant: grant, device: CaptureDevice.camera);
    }

    final List<CameraDescription> list;
    try {
      list = await _cameras();
    } catch (e) {
      debugPrint('VideoNoteCaptureRecorder.cameras: $e');
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
    if (list.isEmpty) {
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
    _available = list;
    final description = list.firstWhere(
      (c) => c.lensDirection == _lens,
      orElse: () => list.first,
    );
    _lens = description.lensDirection;

    final controller = CameraController(
      description,
      // A note is drawn inside a ~200pt circle. `medium` is 480p, which covers
      // that at any device pixel ratio and keeps a 60-second note inside the
      // send path's retained-bytes budget — `veryHigh` would be a 1080p file
      // for a thumbnail-sized bubble.
      ResolutionPreset.medium,
      // Unlike the stills camera, audio is the point: a silent video note is
      // not a message. This is also what makes the microphone grant part of
      // this flow, and why a refusal arrives as an `Audio*` CameraException.
      enableAudio: true,
      // Size is bitrate × duration, not resolution. Left unset, each platform
      // picks ~1.5–2.5 Mbps for 480p, a 12–20 MB minute. A face filling a
      // small circle holds up at Telegram's round-video rate: ~5 MB a minute.
      fps: 30,
      videoBitrate: 700000,
      audioBitrate: 64000,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      final grant = CapturePermissions.grantForCameraCode(e.code);
      if (grant != null) {
        throw CaptureFailure(CaptureFailureKind.permission,
            grant: grant,
            device: e.code.startsWith('Audio')
                ? CaptureDevice.microphone
                : CaptureDevice.camera);
      }
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    } catch (e) {
      // camera_web raises bare UnimplementedErrors rather than
      // CameraException, which is the trap `camera_screen.dart` documents.
      await controller.dispose();
      debugPrint('VideoNoteCaptureRecorder.initialize: $e');
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
    if (_disposed) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onControllerUpdate);
    _controller = controller;
  }

  void _onControllerUpdate() {
    final c = _controller;
    if (c == null || !c.value.hasError) return;
    // A session that has errored is not coming back on its own. Tell whoever is
    // holding the recording, and let them decide — the widget aborts, which
    // deletes the partial file.
    onSessionLost?.call();
  }

  @override
  Future<void> start() async {
    await warm();
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
    // A path is minted even though `camera` chooses its own: the plugin writes
    // into the OS temp directory and hands back an XFile, so what needs
    // tracking is that returned path, not one we picked. [_path] is set in
    // [stop] for that reason, and the sweeper covers the plugin's directory
    // only indirectly — see the note in [stop].
    try {
      await c.startVideoRecording();
    } on CameraException catch (e) {
      final grant = CapturePermissions.grantForCameraCode(e.code);
      if (grant != null) {
        throw CaptureFailure(CaptureFailureKind.permission,
            grant: grant,
            device: e.code.startsWith('Audio')
                ? CaptureDevice.microphone
                : CaptureDevice.camera);
      }
      debugPrint('VideoNoteCaptureRecorder.start: $e');
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
    _recording = true;
    _startedAt = DateTime.now();
  }

  @override
  Future<CaptureOutcome> stop() async {
    final c = _controller;
    final started = _startedAt;
    _startedAt = null;
    if (c == null || !_recording) {
      throw const CaptureFailure(CaptureFailureKind.interrupted);
    }
    _recording = false;

    final XFile file;
    try {
      file = await c.stopVideoRecording();
    } catch (e) {
      debugPrint('VideoNoteCaptureRecorder.stop: $e');
      throw const CaptureFailure(CaptureFailureKind.interrupted);
    }
    // The plugin's own temp file, not one of ours. Tracked from here so every
    // exit below deletes it — this is the file that leaks if a send throws.
    _path = file.path;

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      debugPrint('VideoNoteCaptureRecorder.read: $e');
      await CaptureTempFiles.delete(_path);
      _path = null;
      throw const CaptureFailure(CaptureFailureKind.storage);
    }
    if (bytes.isEmpty) {
      await CaptureTempFiles.delete(_path);
      _path = null;
      throw const CaptureFailure(CaptureFailureKind.storage);
    }

    // Extracted before the file is deleted, and best-effort: a note that sends
    // without a poster is fine, a note that fails to send because its poster
    // could not be made is not. Same contract the gallery video path uses.
    //
    // The `kIsWeb` guard is on this expression rather than relying on the fact
    // that [warm] already refuses on web: `XFile.path` is a `blob:` URL in a
    // browser and reading it is what has no answer there. `video_poster_gate_test`
    // pins the guard at every call site for exactly that reason.
    final poster = kIsWeb ? null : await VideoPoster.extract(file.path);

    await CaptureTempFiles.delete(_path);
    _path = null;
    return CaptureOutcome(
      bytes: bytes,
      contentType: videoNoteContentType,
      duration:
          started == null ? Duration.zero : DateTime.now().difference(started),
      posterBytes: poster,
    );
  }

  @override
  Future<CaptureSegment> stopSegment() async {
    final c = _controller;
    final started = _startedAt;
    _startedAt = null;
    if (c == null || !_recording) {
      throw const CaptureFailure(CaptureFailureKind.interrupted);
    }
    _recording = false;

    // `stopVideoRecording` finalises the file and leaves the capture session —
    // and so the preview — running on both platforms. That is the whole of
    // "the picture stays live while paused".
    final XFile file;
    try {
      file = await c.stopVideoRecording();
    } catch (e) {
      debugPrint('VideoNoteCaptureRecorder.stopSegment: $e');
      throw const CaptureFailure(CaptureFailureKind.interrupted);
    }
    final path = await _adopt(file.path);

    var length = 0;
    try {
      length = await File(path).length();
    } catch (e) {
      debugPrint('VideoNoteCaptureRecorder.stopSegment length: $e');
    }
    if (length == 0) {
      await CaptureTempFiles.delete(path);
      throw const CaptureFailure(CaptureFailureKind.storage);
    }
    return CaptureSegment(
      path: path,
      duration:
          started == null ? Duration.zero : DateTime.now().difference(started),
      contentType: videoNoteContentType,
    );
  }

  /// Moves the plugin's output into [CaptureTempFiles]' folder.
  ///
  /// `camera` writes wherever it likes, and a segment can sit on disk for as
  /// long as the user lingers on the review strip. Inside our folder a crash
  /// in that window is the sweeper's problem; outside it, the file is
  /// nobody's. The extension is kept — AVFoundation picks a reader from it.
  /// A move that fails (another volume, a sandbox quirk) leaves the file where
  /// it was, which is still a working segment.
  Future<String> _adopt(String path) async {
    final dot = path.lastIndexOf('.');
    final ext = dot > path.lastIndexOf('/') ? path.substring(dot + 1) : 'mp4';
    try {
      final target = await CaptureTempFiles.newPath(ext);
      await File(path).rename(target);
      return target;
    } catch (e) {
      debugPrint('VideoNoteCaptureRecorder.adopt: $e');
      return path;
    }
  }

  /// Switches between the front and back lens. A no-op when [canFlip] is
  /// false or a flip is already in flight.
  ///
  /// Works idle, paused and mid-recording. Mid-recording it is
  /// `CameraController.setDescription`, which camera 0.12 routes to the
  /// platform's `setDescriptionWhileRecording` — camera_avfoundation 0.10
  /// swaps the capture input under the running asset writer, and
  /// camera_android_camerax 0.7 rebinds the use cases around a persistent
  /// recording (persistence is the controller's default) — so the take keeps
  /// going in the *same file*, with no segment break. Idle or paused, the same
  /// call disposes and reopens the session on the new lens; the controller
  /// object survives, so the widget's preview just rebuilds.
  ///
  /// The torch goes off first: the front lens has none, and leaving a back
  /// LED lit while the user looks at themselves is a bug report.
  ///
  /// Throws [CaptureFailure] when the new session could not open; a failure
  /// mid-recording is reported through [onSessionLost] by the controller's
  /// error state, as any other lost session is.
  Future<void> flip() async {
    final c = _controller;
    if (c == null || _flipping || !canFlip) return;
    final wantFront = _lens != CameraLensDirection.front;
    final target = _available.firstWhere(
      (d) => wantFront
          ? d.lensDirection == CameraLensDirection.front
          : d.lensDirection != CameraLensDirection.front,
      orElse: () => c.description,
    );
    if (target.name == c.description.name) return;
    _flipping = true;
    try {
      if (_torch) await setTorch(false);
      await c.setDescription(target);
      _lens = target.lensDirection;
      _torchRefused = false;
    } on CameraException catch (e) {
      debugPrint('VideoNoteCaptureRecorder.flip: $e');
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    } finally {
      _flipping = false;
    }
  }

  /// The back LED, held on (FlashMode.torch) for as long as it is wanted —
  /// paused, recording, or framing. Ignored when [hasTorch] is false.
  ///
  /// A refusal flips [hasTorch] to false rather than throwing: the torch is a
  /// nicety, and the UI's answer to "no torch" is to hide the button, not to
  /// show an error.
  Future<void> setTorch(bool on) async {
    final c = _controller;
    if (c == null || (on && !hasTorch) || on == _torch) return;
    try {
      await c.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      _torch = on;
    } catch (e) {
      debugPrint('VideoNoteCaptureRecorder.setTorch: $e');
      if (on) _torchRefused = true;
      _torch = false;
    }
  }

  @override
  Future<void> cancel() async {
    _startedAt = null;
    final c = _controller;
    if (c != null && _recording) {
      _recording = false;
      try {
        final file = await c.stopVideoRecording();
        await CaptureTempFiles.delete(file.path);
      } catch (e) {
        debugPrint('VideoNoteCaptureRecorder.cancel: $e');
      }
    }
    _recording = false;
    await CaptureTempFiles.delete(_path);
    _path = null;
  }

  /// Lets the capture session go without tearing this object down.
  ///
  /// The backgrounding half of the lifecycle: the OS takes the session anyway,
  /// and a controller held through it comes back with an error on iOS rather
  /// than a working preview. [warm] rebuilds it on resume.
  Future<void> release() async {
    final c = _controller;
    if (c == null) return;
    _controller = null;
    _recording = false;
    // The OS drops the LED with the session; the flag has to follow.
    _torch = false;
    c.removeListener(_onControllerUpdate);
    try {
      await c.dispose();
    } catch (e) {
      debugPrint('VideoNoteCaptureRecorder.release: $e');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    onSessionLost = null;
    await cancel();
    await release();
  }
}
