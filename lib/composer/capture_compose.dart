import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../media/video_poster.dart';
import 'capture_recorder.dart';

/// Joining, trimming and previewing a paused-and-resumed recording.
///
/// [CaptureRecorder.stopSegment] leaves one file per stretch between pauses;
/// this is where they become one message again. The heavy lifting is native —
/// `monkeyhub/media_compose`, in `ios/Runner/MediaCompose.swift` and
/// `android/.../MediaCompose.kt` — because joining two MP4s is a container
/// operation that Dart has no business doing, and both platforms can do it
/// without re-encoding.
///
/// **Where it runs.** iOS and Android only. The composer offers recording on
/// desktop too (voice notes via `record`), but nothing there answers the
/// channel: a compose that needs native work on desktop throws
/// [CaptureFailure] with [CaptureFailureKind.unavailable]. Check
/// [captureComposeSupported] before offering pause or trim at all — a
/// multi-segment recording on a host that cannot join it is a recording that
/// can never be sent. A single untrimmed take never touches the channel (see
/// [composeCapture]), so the plain hold-to-record path works everywhere it did
/// before.

const _channel = MethodChannel('monkeyhub/media_compose');

/// Whether this host can join segments and trim. False on web and desktop,
/// where the UI should offer neither pause nor trim — the single-take path
/// still works there.
bool get captureComposeSupported =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// The wall-clock length of all [segments] laid end to end — the timeline the
/// review strip draws and `trimStart`/`trimEnd` are measured on.
Duration totalDuration(List<CaptureSegment> segments) =>
    segments.fold(Duration.zero, (sum, s) => sum + s.duration);

/// What [composeCapture] will actually do with a request, worked out without
/// touching a file. Separate so the "does this need native at all" decision
/// is testable on a host with no native side.
@visibleForTesting
class ComposePlan {
  const ComposePlan({required this.native, this.startMs, this.endMs});

  /// False is the fast path: one segment, nothing cut, bytes read as-is.
  final bool native;

  /// Null means "from the beginning" / "to the end" — normalised so a trim
  /// that covers everything is no trim, and does not cost a native pass.
  final int? startMs;
  final int? endMs;
}

/// Normalises a trim request against [segments]' joined timeline.
///
/// A trim handle dragged back to the edge is the same as no trim; a start at
/// or past the end is nothing at all, which is [CaptureFailureKind.tooShort]
/// (silent, exactly as a mis-tapped hold is).
@visibleForTesting
ComposePlan planCompose(
  List<CaptureSegment> segments, {
  Duration? trimStart,
  Duration? trimEnd,
}) {
  if (segments.isEmpty) {
    throw const CaptureFailure(CaptureFailureKind.tooShort);
  }
  final total = totalDuration(segments).inMilliseconds;
  int? start = trimStart?.inMilliseconds;
  int? end = trimEnd?.inMilliseconds;
  if (start != null && start <= 0) start = null;
  // The wall-clock total runs a frame or so long of the file's own end, so a
  // handle within 50 ms of the end is the end.
  if (end != null && end >= total - 50) end = null;
  if ((start ?? 0) >= (end ?? total)) {
    throw const CaptureFailure(CaptureFailureKind.tooShort);
  }
  return ComposePlan(
    native: segments.length > 1 || start != null || end != null,
    startMs: start,
    endMs: end,
  );
}

/// Turns [segments] into one sendable recording.
///
/// Joins them in order, trims to [trimStart, trimEnd) on the joined timeline
/// (null = untouched), reads the bytes, makes the poster for a video note,
/// and answers a [CaptureOutcome] carrying the *true* duration of what was
/// produced — the native side measures its output rather than trusting the
/// wall clock.
///
/// **Fast path:** one segment and no trim makes no native call at all; the
/// file is read as the recorder wrote it, so the never-paused case behaves
/// exactly as `CaptureRecorder.stop` did.
///
/// **Trim precision.** Voice notes cut at the sample (iOS re-encodes AAC
/// through the M4A preset; Android drops whole AAC frames, ~23 ms). A video
/// note on Android starts at the keyframe at or before [trimStart] — the
/// camera encoders put one every second or so, so the cut can land up to
/// ~1 s early. iOS cuts video exactly (an edit list on passthrough).
///
/// **Files.** On success every segment file and every intermediate is
/// deleted, same discipline as `stop`. On failure only the intermediates go:
/// the segments stay with the caller, so it can retry — e.g. without the trim
/// when the kind is [CaptureFailureKind.unavailable] and there is a single
/// segment — or let them go with [discardSegments].
///
/// Failure kinds the UI should tell apart:
/// - [CaptureFailureKind.unavailable]: no native implementation on this host
///   (desktop). Do not retry with segments > 1; see [captureComposeSupported].
/// - [CaptureFailureKind.unknown]: the native join/export failed on a
///   supported device. Retrying will not help; falling back to the fast path
///   (if there is one segment) or discarding is the answer.
/// - [CaptureFailureKind.storage]: the output was empty or unreadable.
/// - [CaptureFailureKind.tooShort]: the trim left nothing.
Future<CaptureOutcome> composeCapture({
  required List<CaptureSegment> segments,
  required bool video,
  Duration? trimStart,
  Duration? trimEnd,
}) async {
  final plan = planCompose(segments, trimStart: trimStart, trimEnd: trimEnd);
  final contentType =
      video ? videoNoteContentType : segments.first.contentType;

  String outPath;
  Duration duration;
  String? intermediate;
  if (!plan.native) {
    outPath = segments.single.path;
    duration = segments.single.duration;
  } else {
    if (kIsWeb) throw const CaptureFailure(CaptureFailureKind.unavailable);
    intermediate = await CaptureTempFiles.newPath(video ? 'mp4' : 'm4a');
    outPath = intermediate;
    final Map<String, Object?>? reply;
    try {
      reply = await _channel.invokeMapMethod<String, Object?>('compose', {
        'paths': [for (final s in segments) s.path],
        'outPath': outPath,
        'startMs': plan.startMs,
        'endMs': plan.endMs,
        // The timeline the cut was placed on; native maps the cut onto the
        // real media length as a share of it.
        'timelineMs': totalDuration(segments).inMilliseconds,
        'video': video,
      });
    } on MissingPluginException {
      await CaptureTempFiles.delete(intermediate);
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    } catch (e) {
      debugPrint('composeCapture: $e');
      await CaptureTempFiles.delete(intermediate);
      throw const CaptureFailure(CaptureFailureKind.unknown);
    }
    final ms = reply?['durationMs'];
    if (ms is! num || ms <= 0) {
      await CaptureTempFiles.delete(intermediate);
      throw const CaptureFailure(CaptureFailureKind.unknown);
    }
    duration = Duration(milliseconds: ms.round());
  }

  Uint8List bytes;
  try {
    bytes = await File(outPath).readAsBytes();
  } catch (e) {
    debugPrint('composeCapture.read: $e');
    await CaptureTempFiles.delete(intermediate);
    throw const CaptureFailure(CaptureFailureKind.storage);
  }
  if (bytes.isEmpty) {
    await CaptureTempFiles.delete(intermediate);
    throw const CaptureFailure(CaptureFailureKind.storage);
  }

  // Best-effort and before any delete, for the reasons
  // `VideoNoteCaptureRecorder.stop` gives. `kIsWeb` is spelled out at the call
  // site because `video_poster_gate_test` pins it there.
  final poster = video && !kIsWeb ? await VideoPoster.extract(outPath) : null;

  await CaptureTempFiles.delete(intermediate);
  await discardSegments(segments);
  return CaptureOutcome(
    bytes: bytes,
    contentType: contentType,
    duration: duration,
    posterBytes: poster,
  );
}

/// Deletes every segment's file. For a recording thrown away from the review
/// strip, or after a compose failure the caller is not going to retry.
/// Never throws.
Future<void> discardSegments(List<CaptureSegment> segments) async {
  for (final s in segments) {
    await CaptureTempFiles.delete(s.path);
  }
}

/// Where each filmstrip frame comes from: the centre of each of [count]
/// equal slices of the joined timeline, mapped back to a segment and an
/// offset inside it.
@visibleForTesting
List<({int segment, Duration at})> filmstripTimes(
  List<CaptureSegment> segments,
  int count,
) {
  final total = totalDuration(segments).inMicroseconds;
  if (count <= 0 || segments.isEmpty || total <= 0) return const [];
  final out = <({int segment, Duration at})>[];
  for (var i = 0; i < count; i++) {
    var t = (total * (i + 0.5) / count).round();
    var seg = 0;
    while (seg < segments.length - 1 &&
        t >= segments[seg].duration.inMicroseconds) {
      t -= segments[seg].duration.inMicroseconds;
      seg++;
    }
    out.add((segment: seg, at: Duration(microseconds: t)));
  }
  return out;
}

/// [count] JPEG frames evenly spaced across the joined timeline of video
/// [segments], each [height] px tall, for the trim strip.
///
/// Always [count] long when any frame could be made — a frame the decoder
/// refused (a timestamp past a short segment's last frame, mostly) is filled
/// with its nearest neighbour, so the strip can lay out fixed tiles. Empty on
/// web and desktop, where `video_thumbnail` does not exist, and when nothing
/// decoded at all. Never throws. Runs one frame at a time: the retriever is
/// not cheap and this is not on a path where seconds matter.
Future<List<Uint8List>> filmstrip(
  List<CaptureSegment> segments, {
  int count = 8,
  int height = 64,
}) async {
  if (kIsWeb) return const [];
  final times = filmstripTimes(segments, count);
  final frames = <Uint8List?>[];
  for (final t in times) {
    Uint8List? bytes;
    try {
      bytes = await VideoThumbnail.thumbnailData(
        video: segments[t.segment].path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: height,
        timeMs: t.at.inMilliseconds,
        quality: 60,
      );
    } catch (e) {
      debugPrint('filmstrip: $e');
    }
    frames.add(bytes == null || bytes.isEmpty ? null : bytes);
  }
  return fillGaps(frames);
}

/// Replaces each null with its nearest non-null neighbour (earlier wins a
/// tie). Empty when every entry is null.
@visibleForTesting
List<T> fillGaps<T extends Object>(List<T?> items) {
  if (items.every((e) => e == null)) return const [];
  final out = <T>[];
  for (var i = 0; i < items.length; i++) {
    final hit = items[i];
    if (hit != null) {
      out.add(hit);
      continue;
    }
    for (var d = 1;; d++) {
      final before = i - d >= 0 ? items[i - d] : null;
      if (before != null) {
        out.add(before);
        break;
      }
      final after = i + d < items.length ? items[i + d] : null;
      if (after != null) {
        out.add(after);
        break;
      }
    }
  }
  return out;
}

/// The voice-note waveform across every segment, resampled to [bars] values
/// in 0..1.
///
/// Each bar is the *peak* of the samples it covers rather than their mean: a
/// mean flattens speech into a mumble-coloured band, and the peak is what
/// makes a waveform read as the shape of what was said. When there are fewer
/// samples than bars, samples are stretched across several bars. All zeros
/// when nothing was metered (a desktop recorder without amplitude, or a
/// sub-tick recording), so the strip can always draw [bars] bars.
List<double> waveform(List<CaptureSegment> segs, int bars) {
  if (bars <= 0) return const [];
  final samples = [for (final s in segs) ...s.levels];
  final n = samples.length;
  if (n == 0) return List<double>.filled(bars, 0);
  return List<double>.generate(bars, (i) {
    final start = i * n ~/ bars;
    final end = math.max(start + 1, (i + 1) * n ~/ bars);
    var peak = 0.0;
    for (var j = start; j < end && j < n; j++) {
      peak = math.max(peak, samples[j]);
    }
    return peak.clamp(0.0, 1.0);
  });
}
