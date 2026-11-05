import 'call_media.dart' show videoQualityPresets;
import 'call_models.dart';
import 'call_stats_monitor.dart';

/// A call whose connection can't carry the camera's tier: drop [from] to
/// [to]. What the call does with it depends on
/// `SettingsStore.autoLowerVideoQuality`: apply it and say so, or offer it.
class VideoQualityAdvice {
  const VideoQualityAdvice({required this.from, required this.to});
  final VideoQualityTier from;
  final VideoQualityTier to;

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

/// The highest tier first; [VideoQualityTier.auto] is the floor. Below it
/// libwebrtc does the rest by itself, shedding resolution as the link
/// shrinks (see `configureVideoSenders`), so there is nothing to step to.
const List<VideoQualityTier> _tiersHighToLow = [
  VideoQualityTier.uhd4k,
  VideoQualityTier.hd1080,
  VideoQualityTier.auto,
];

/// The share of a tier's bitrate cap the link must carry for the tier to
/// be worth its camera. Under it the encoder is starving a 4K or 1080p
/// capture: the picture comes out no sharper than a lower tier's, the phone
/// spends the heat of the bigger capture anyway, and every spare bit goes
/// to fighting the link instead of to the picture.
const double kTierHeadroom = 0.6;

/// Watches the 2-second stats polls of a call for a camera tier the link
/// can't carry, and advises a step down. Pure: no timers, no service; the
/// caller feeds it snapshots and the current tier.
///
/// A poll is strained when, at the current tier:
///   - the send-side bandwidth estimate is under [kTierHeadroom] of the
///     tier's cap, or
///   - the encoder says it is limited by bandwidth and sends under half the
///     cap, or
///   - the encoder says it is limited by CPU: the phone can't encode this
///     tier (a 4K camera heating up).
/// [window] strained polls in a row (10 s at the default) give advice. The
/// first [warmup] after a [reset] never count: libwebrtc's bandwidth
/// estimate starts low and climbs for several seconds after a connect or a
/// camera swap, and reading that ramp as a weak link would downgrade every
/// call.
class VideoQualityGovernor {
  VideoQualityGovernor({
    this.window = 5,
    this.warmup = const Duration(seconds: 15),
  });

  final int window;
  final Duration warmup;

  DateTime? _since;
  int _strained = 0;

  /// Start over: a new call, a connect, a tier change.
  void reset(DateTime now) {
    _since = now;
    _strained = 0;
  }

  /// Feeds one poll. Returns advice once [window] strained polls in a row
  /// land past the warmup, then starts over (so the next advice needs a
  /// fresh window, never a poll later).
  VideoQualityAdvice? observe(
    CallQualitySnapshot q,
    VideoQualityTier tier,
    DateTime now,
  ) {
    final since = _since ??= now;
    if (tier == VideoQualityTier.auto) {
      _strained = 0;
      return null;
    }
    if (now.difference(since) < warmup) return null;
    if (!isStrained(q, tier)) {
      _strained = 0;
      return null;
    }
    _strained++;
    if (_strained < window) return null;
    reset(now);
    return VideoQualityAdvice(from: tier, to: fittingTier(q, tier));
  }

  /// Whether [q] says the link can't carry [tier]. See the class doc.
  static bool isStrained(CallQualitySnapshot q, VideoQualityTier tier) {
    final capKbps = videoQualityPresets[tier]!.maxBitrate / 1000;
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
  ) {
    final below = _tiersHighToLow
        .skipWhile((t) => t != tier)
        .skip(1)
        .toList(growable: false);
    if (below.isEmpty) return VideoQualityTier.auto;
    final avail = q.availableOutKbps;
    if (avail == null || q.limitationReason == 'cpu') return below.first;
    for (final t in below) {
      final capKbps = videoQualityPresets[t]!.maxBitrate / 1000;
      if (avail >= capKbps * kTierHeadroom) return t;
    }
    return VideoQualityTier.auto;
  }
}
