import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_media.dart' show videoQualityPresets, scaleCameraSender;
import 'call_models.dart';
import 'call_stats_monitor.dart';

/// Step the camera's SEND tier from [from] to [to]: down when the link
/// can't carry it, back up when it can again.
class VideoQualityAdvice {
  const VideoQualityAdvice({required this.from, required this.to});
  final VideoQualityTier from;
  final VideoQualityTier to;

  bool get down => tierRank(to) < tierRank(from);

  @override
  bool operator ==(Object other) =>
      other is VideoQualityAdvice && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'VideoQualityAdvice(${from.name} -> ${to.name})';
}

/// What the in-call banner says about the camera's tier.
class VideoQualityNotice {
  const VideoQualityNotice({
    required this.from,
    required this.to,
    required this.applied,
  });
  final VideoQualityTier from;
  final VideoQualityTier to;

  /// True: the call already dropped to [to] (auto-lowering on). False: it
  /// offers to, and keeps [from] until the user says so.
  final bool applied;
}

/// What a call exposes for the weak-link banner, 1:1 and group alike.
abstract interface class VideoQualityNoticeSource {
  ValueListenable<VideoQualityNotice?> get qualityNotice;
  void dismissQualityNotice();

  /// The banner's "Lower": send [tier] for the rest of this call.
  Future<void> lowerVideoQualityForCall(VideoQualityTier tier);
}

/// 0 for [VideoQualityTier.auto], up from there.
int tierRank(VideoQualityTier t) => switch (t) {
      VideoQualityTier.auto => 0,
      VideoQualityTier.hd1080 => 1,
      VideoQualityTier.uhd4k => 2,
    };

VideoQualityTier _tierAt(int rank) => switch (rank) {
      <= 0 => VideoQualityTier.auto,
      1 => VideoQualityTier.hd1080,
      _ => VideoQualityTier.uhd4k,
    };

/// The share of a tier's bitrate cap the link must carry for the tier to
/// be worth sending. Under it the encoder is starving the bigger picture:
/// it comes out no sharper than a lower tier's, and every spare bit goes to
/// fighting the link instead of to the picture.
const double kTierHeadroom = 0.6;

/// Watches a link's 2-second stats polls and moves its SEND tier: down when
/// the link can't carry it, back up (toward [ceiling], the tier the camera
/// captures at) when it can again. Pure: no timers, no service; the caller
/// feeds it polls.
///
/// A poll is strained when, at the current tier:
///   - the send-side bandwidth estimate is under [kTierHeadroom] of the
///     tier's cap, or
///   - the encoder says it is limited by bandwidth and sends under half the
///     cap, or
///   - the encoder says it is limited by CPU: the phone can't encode this
///     tier (a 4K camera heating up).
/// [window] strained polls in a row (10 s) step down, to the highest tier
/// the estimate fits. [upWindow] calm polls in a row (30 s) step up one
/// tier, as a probe: a link that strains again within [upWindow] of a
/// probe doubles the wait before the next one (up to 8x), so a link that
/// can't hold the higher tier isn't bounced up and down every half minute.
/// The first [warmup] after a [reset] never count: libwebrtc's bandwidth
/// estimate starts low and climbs for several seconds after a connect, and
/// reading that ramp as a weak link would downgrade every call.
class VideoQualityGovernor {
  VideoQualityGovernor({
    this.window = 5,
    this.upWindow = 15,
    this.warmup = const Duration(seconds: 15),
  });

  final int window;
  final int upWindow;
  final Duration warmup;

  DateTime? _since;
  int _strained = 0;
  int _calm = 0;
  int _upBackoff = 1;
  DateTime? _lastUpAt;

  /// Start over: a new call, a connect, a tier the user picked.
  void reset(DateTime now) {
    _since = now;
    _strained = 0;
    _calm = 0;
  }

  /// Forget the up-probe history too: a fresh call.
  void resetAll(DateTime now) {
    reset(now);
    _upBackoff = 1;
    _lastUpAt = null;
  }

  /// Feeds one poll. [current] is the tier being sent, [ceiling] the tier
  /// the camera captures at; [capKbpsOf] the encoder cap of a tier on this
  /// link (a mesh tapers it per peer). [allowUp] false holds a lowered tier
  /// (the user lowered it by hand).
  VideoQualityAdvice? observe(
    CallQualitySnapshot q, {
    required VideoQualityTier current,
    required VideoQualityTier ceiling,
    required double Function(VideoQualityTier) capKbpsOf,
    required DateTime now,
    bool allowUp = true,
  }) {
    final since = _since ??= now;
    if (now.difference(since) < warmup) return null;
    final rank = tierRank(current);
    final strained =
        rank > 0 && isStrained(q, capKbpsOf(current));
    if (strained) {
      _calm = 0;
      _strained++;
      if (_strained < window) return null;
      final last = _lastUpAt;
      if (last != null &&
          now.difference(last) < Duration(seconds: upWindow * 2 + window * 2)) {
        _upBackoff = math.min(_upBackoff * 2, 8);
      }
      reset(now);
      return VideoQualityAdvice(
        from: current,
        to: fittingTier(q, current, capKbpsOf),
      );
    }
    _strained = 0;
    if (!allowUp || rank >= tierRank(ceiling) || q.quality == CallQuality.poor) {
      _calm = 0;
      return null;
    }
    _calm++;
    if (_calm < upWindow * _upBackoff) return null;
    reset(now);
    _lastUpAt = now;
    return VideoQualityAdvice(from: current, to: _tierAt(rank + 1));
  }

  /// Whether [q] says the link can't carry a tier capped at [capKbps].
  static bool isStrained(CallQualitySnapshot q, double capKbps) {
    final avail = q.availableOutKbps;
    if (avail != null && avail < capKbps * kTierHeadroom) return true;
    final reason = q.limitationReason;
    if (reason == 'cpu') return true;
    final out = q.outKbps;
    if (reason == 'bandwidth' && out != null && out < capKbps * 0.5) {
      return true;
    }
    return false;
  }

  /// The highest tier below [tier] the link can carry, by the bandwidth
  /// estimate; one step down when there is no estimate, or the strain was
  /// the CPU's. Never below [VideoQualityTier.auto].
  static VideoQualityTier fittingTier(
    CallQualitySnapshot q,
    VideoQualityTier tier,
    double Function(VideoQualityTier) capKbpsOf,
  ) {
    final rank = tierRank(tier);
    if (rank == 0) return VideoQualityTier.auto;
    final avail = q.availableOutKbps;
    if (avail == null || q.limitationReason == 'cpu') return _tierAt(rank - 1);
    for (var r = rank - 1; r > 0; r--) {
      final t = _tierAt(r);
      if (avail >= capKbpsOf(t) * kTierHeadroom) return t;
    }
    return VideoQualityTier.auto;
  }
}

/// The encoder cap of [t] for a 1:1 link.
double soloCapKbps(VideoQualityTier t) =>
    videoQualityPresets[t]!.maxBitrate / 1000;

/// How far the encoder shrinks a camera capturing at [captureShortSide]
/// (the frame's shorter edge, in pixels) to send [send]. 1 when it captures
/// at or under the tier's size.
double sendScaleFor(int? captureShortSide, VideoQualityTier send) {
  final target = videoQualityPresets[send]!.idealHeight;
  final source = captureShortSide ?? target;
  if (source <= target) return 1.0;
  return source / target;
}

/// The shorter edge of the frames [track] captures, from the plugin's track
/// settings; null when it doesn't say.
int? captureShortSide(MediaStreamTrack? track) {
  if (track == null) return null;
  try {
    final s = track.getSettings();
    final w = s['width'];
    final h = s['height'];
    if (w is num && h is num) return math.min(w, h).toInt();
  } catch (_) {}
  return null;
}

/// One link's adaptive send tier: the [VideoQualityGovernor] for it, and
/// the mechanism, which is the encoder's, never the camera's. The camera
/// keeps capturing at the chosen tier; stepping down asks the encoder to
/// shrink each frame before it is sent (`scaleResolutionDownBy`) and lowers
/// its bitrate cap, the way FaceTime and WhatsApp do. One parameter change
/// on a running encoder: no camera restart, no black frame, no flash, and
/// stepping back up is the same change in reverse.
class SendQualityLadder {
  SendQualityLadder({VideoQualityGovernor? governor})
      : governor = governor ?? VideoQualityGovernor();

  final VideoQualityGovernor governor;

  /// The tier being sent, null while it is the camera's own.
  VideoQualityTier? sendTier;

  /// The user lowered it by hand: no stepping back up this call.
  bool held = false;

  VideoQualityTier current(VideoQualityTier ceiling) {
    final s = sendTier;
    if (s == null || tierRank(s) >= tierRank(ceiling)) return ceiling;
    return s;
  }

  void clear(DateTime now) {
    sendTier = null;
    held = false;
    governor.resetAll(now);
  }

  /// Sets the send tier and applies it to [sender] (the camera's), with
  /// [capKbpsOf] for the bitrate. [captureTrack] tells the capture size.
  Future<void> apply(
    VideoQualityTier tier, {
    required VideoQualityTier ceiling,
    required RTCRtpSender? sender,
    required MediaStreamTrack? captureTrack,
    required double Function(VideoQualityTier) capKbpsOf,
  }) async {
    sendTier = tierRank(tier) >= tierRank(ceiling) ? null : tier;
    if (sender == null) return;
    final send = current(ceiling);
    await scaleCameraSender(
      sender,
      scale: sendScaleFor(captureShortSide(captureTrack), send),
      maxBitrate: (capKbpsOf(send) * 1000).round(),
    );
  }

  /// [apply] without waiting, for a stats tick.
  void applyLater(
    VideoQualityTier tier, {
    required VideoQualityTier ceiling,
    required RTCRtpSender? sender,
    required MediaStreamTrack? captureTrack,
    required double Function(VideoQualityTier) capKbpsOf,
  }) =>
      unawaited(apply(
        tier,
        ceiling: ceiling,
        sender: sender,
        captureTrack: captureTrack,
        capKbpsOf: capKbpsOf,
      ));
}

/// What [CallQualityAdapter] needs to know about one link: the camera
/// sender on it, and the encoder cap of each tier there (a mesh tapers it
/// per peer).
typedef QualityLink = ({
  RTCRtpSender? sender,
  double Function(VideoQualityTier) capKbpsOf,
});

/// The whole weak-link video policy of one call, shared by the 1:1 call (one
/// link) and the group mesh (one link per peer, each with its own ladder, so
/// one peer on a bad network costs only that peer's picture).
///
/// Two mechanisms, each where it is better:
///   - The encoder scale ([SendQualityLadder]) for every step, down and back
///     up. Instant and invisible: the camera keeps running, the picture
///     goes soft for a moment and sharpens again, the way FaceTime does it.
///   - Re-capturing the camera at the lower tier, only when the shrink is
///     not enough by itself: the encoder is CPU-limited (capturing 4K to
///     send 720p still heats the phone), or every link has been lowered for
///     [recaptureAfter]. One brief hitch, saved for when it buys something:
///     the phone stops capturing pixels nobody receives. A step back up past
///     the capture tier re-captures up again.
class CallQualityAdapter implements VideoQualityNoticeSource {
  CallQualityAdapter({
    required this.savedTier,
    required this.autoLower,
    required this.linkOf,
    required this.captureTrack,
    required this.recaptureCamera,
    this.recaptureAfter = const Duration(minutes: 2),
  });

  /// The user's saved tier: the ceiling everything steps back up to.
  final VideoQualityTier Function() savedTier;

  /// `SettingsStore.autoLowerVideoQuality`.
  final bool Function() autoLower;

  /// The link named [id], null once it is gone.
  final QualityLink? Function(String id) linkOf;

  /// The camera track being captured, for its size.
  final MediaStreamTrack? Function() captureTrack;

  /// Re-acquires the camera at a tier (the service's own camera swap).
  final Future<void> Function(VideoQualityTier tier) recaptureCamera;

  final Duration recaptureAfter;

  final ValueNotifier<VideoQualityNotice?> _notice = ValueNotifier(null);
  final Map<String, SendQualityLadder> _ladders = {};
  final Map<String, DateTime> _lowSince = {};
  final Set<VideoQualityTier> _offered = {};
  bool _announced = false;
  bool _recapturing = false;

  /// The camera's capture tier when it differs from [savedTier].
  VideoQualityTier? _captureOverride;

  @override
  ValueListenable<VideoQualityNotice?> get qualityNotice => _notice;

  /// The tier the camera captures at.
  VideoQualityTier get captureTier => _captureOverride ?? savedTier();

  /// What the in-call quality control shows: the best tier any link sends.
  VideoQualityTier get liveTier {
    final saved = savedTier();
    if (_ladders.isEmpty) return captureTier;
    var best = VideoQualityTier.auto;
    for (final l in _ladders.values) {
      final t = l.current(saved);
      if (tierRank(t) > tierRank(best)) best = t;
    }
    return best;
  }

  bool get _held => _ladders.values.any((l) => l.held);

  @override
  void dismissQualityNotice() => _notice.value = null;

  /// A new call, a teardown, or the user picking a tier: everything back to
  /// the saved tier, nothing announced.
  void reset() {
    _ladders.clear();
    _lowSince.clear();
    _offered.clear();
    _announced = false;
    _captureOverride = null;
    _notice.value = null;
  }

  /// A link (re)connected: its warmup starts over.
  void connected(String id, DateTime now) =>
      (_ladders[id] ??= SendQualityLadder()).governor.reset(now);

  /// A link went away.
  void forget(String id) {
    _ladders.remove(id);
    _lowSince.remove(id);
  }

  /// Re-applies link [id]'s send tier after its encoder was re-tuned (a
  /// renegotiation, a camera swap). Nothing to do while it sends what the
  /// camera captures.
  Future<void> reapply(String id) async {
    final ladder = _ladders[id];
    if (_captureOverride == null && ladder?.sendTier == null) return;
    final link = linkOf(id);
    if (link == null) return;
    await (ladder ?? SendQualityLadder()).apply(
      ladder?.current(savedTier()) ?? captureTier,
      ceiling: savedTier(),
      sender: link.sender,
      captureTrack: captureTrack(),
      capKbpsOf: link.capKbpsOf,
    );
  }

  Future<void> _reapplyAll() async {
    for (final id in _ladders.keys.toList(growable: false)) {
      await reapply(id);
    }
  }

  Future<void> _setSend(String id, VideoQualityTier tier, DateTime now) async {
    final ladder = _ladders[id] ??= SendQualityLadder();
    final link = linkOf(id);
    final saved = savedTier();
    ladder.sendTier = tierRank(tier) >= tierRank(saved) ? null : tier;
    if (ladder.sendTier == null) {
      _lowSince.remove(id);
    } else {
      _lowSince.putIfAbsent(id, () => now);
    }
    // Up past what the camera captures: the camera comes up first, then
    // every link's scale is worked out against the new size.
    if (tierRank(tier) > tierRank(captureTier)) {
      await _recapture(tier);
      return;
    }
    if (link == null) return;
    await ladder.apply(
      tier,
      ceiling: saved,
      sender: link.sender,
      captureTrack: captureTrack(),
      capKbpsOf: link.capKbpsOf,
    );
  }

  Future<void> _recapture(VideoQualityTier tier) async {
    if (_recapturing || tier == captureTier) return;
    _recapturing = true;
    try {
      _captureOverride = tier == savedTier() ? null : tier;
      debugPrint('[Quality] camera re-captured at ${tier.name}');
      await recaptureCamera(tier);
      await _reapplyAll();
    } finally {
      _recapturing = false;
    }
  }

  /// The highest tier any link sends.
  VideoQualityTier _maxSend() {
    final saved = savedTier();
    var best = VideoQualityTier.auto;
    for (final l in _ladders.values) {
      final t = l.current(saved);
      if (tierRank(t) > tierRank(best)) best = t;
    }
    return best;
  }

  /// One stats poll of link [id].
  void onPoll(String id, CallQualitySnapshot q, DateTime now) {
    final link = linkOf(id);
    if (link == null) return;
    final saved = savedTier();
    final ladder = _ladders[id] ??= SendQualityLadder()..governor.reset(now);
    final advice = ladder.governor.observe(
      q,
      current: ladder.current(saved),
      ceiling: saved,
      capKbpsOf: link.capKbpsOf,
      now: now,
      allowUp: autoLower() && !_held,
    );
    if (advice == null) {
      _maybeRecaptureLow(now);
      return;
    }
    debugPrint('[Quality] link $id: $advice');
    if (!advice.down) {
      unawaited(_setSend(id, advice.to, now));
      // The banner said it got worse; it is better now.
      if (_notice.value?.applied ?? false) _notice.value = null;
      return;
    }
    if (autoLower()) {
      unawaited(_setSend(id, advice.to, now).then((_) {
        // A phone that can't encode the tier: shrinking still captures and
        // scales every big frame, so capture smaller too.
        if (q.limitationReason == 'cpu') unawaited(_recapture(_maxSend()));
      }));
      if (!_announced) {
        _announced = true;
        _notice.value = VideoQualityNotice(
          from: advice.from,
          to: advice.to,
          applied: true,
        );
      }
    } else if (_offered.add(advice.from)) {
      _notice.value = VideoQualityNotice(
        from: advice.from,
        to: advice.to,
        applied: false,
      );
    }
  }

  /// Every link lowered for [recaptureAfter]: capture at what is sent.
  void _maybeRecaptureLow(DateTime now) {
    if (_recapturing || _ladders.isEmpty) return;
    final target = _maxSend();
    if (tierRank(target) >= tierRank(captureTier)) return;
    for (final id in _ladders.keys) {
      final since = _lowSince[id];
      if (since == null || now.difference(since) < recaptureAfter) return;
    }
    unawaited(_recapture(target));
  }

  /// The banner's "Lower": every link sends [tier] for the rest of the
  /// call, and nothing steps back up by itself.
  @override
  Future<void> lowerVideoQualityForCall(VideoQualityTier tier) async {
    _notice.value = null;
    final now = DateTime.now();
    for (final id in _ladders.keys.toList(growable: false)) {
      _ladders[id]!.held = true;
      await _setSend(id, tier, now);
    }
  }

  void dispose() => _notice.dispose();
}
