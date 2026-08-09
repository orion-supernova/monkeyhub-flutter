/// The location half of a `ChatMessage`, and every rule about when a live share
/// counts as over.
///
/// Lives here rather than on the bubble because three surfaces have to agree
/// about it — the transcript bubble, the sender's own "you are sharing" control,
/// and the publisher that decides whether to keep spending GPS — and because
/// every one of those rules is testable without a device, a network or a widget
/// tree. Anything in this file can be exercised by handing it a `now`.
library;

import 'dart:math' as math;

/// How long a live share may be started for.
///
/// A closed set, not a picker with a free number. Fifteen minutes, an hour and
/// eight hours is what the large messengers converged on and the reasoning is
/// sound enough to copy rather than re-derive: meeting someone right now, an
/// outing, a whole day out. A free duration invites the value this feature must
/// never have — "until I turn it off" — which in practice means until the
/// person forgets.
///
/// Mirrored server-side in `LIVE_SHARE_DURATIONS_MS` (backend/convex/messages.ts)
/// and validated there, because the client offering three buttons is a UI and
/// not a guarantee. Keep the two in step.
enum LiveShareDuration {
  fifteenMinutes(Duration(minutes: 15)),
  oneHour(Duration(hours: 1)),
  eightHours(Duration(hours: 8));

  const LiveShareDuration(this.duration);

  final Duration duration;

  int get milliseconds => duration.inMilliseconds;
}

/// What a location bubble is currently showing.
enum LiveShareState {
  /// Not a live share at all — one fix, sent once, true forever after.
  fixed,

  /// Running: the position is being refreshed and the deadline is in the future.
  live,

  /// Was live and no longer is — stopped by the sharer, or reached its deadline.
  /// Deliberately distinct from [fixed] rather than decaying into it: a share
  /// that has ended is showing where somebody *was*, and a bubble that quietly
  /// became indistinguishable from a static one would be claiming otherwise.
  ended,
}

/// Everything a location message carries, bundled.
///
/// The fields live flat on `ChatMessage` (matching the wire, and matching how
/// every other attachment's metadata is stored there); this is the view of them
/// that has behaviour. `ChatMessage.locationShare` builds one on demand.
class LocationShare {
  const LocationShare({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.liveExpiresAt,
    this.liveUpdatedAt,
    this.liveEndedAt,
  });

  final double latitude;
  final double longitude;

  /// Horizontal accuracy in metres, as the device reported it. Null when the
  /// platform didn't say — which is common on desktop and on web, where a fix
  /// can come from a Wi-Fi lookup that is honestly a kilometre wide.
  ///
  /// Null means "unknown", never "perfect". The preview draws no accuracy ring
  /// at all in that case rather than picking a plausible-looking radius.
  final double? accuracyM;

  /// When this share stops on its own. Non-null iff this is (or was) a live
  /// share — [isLive] reads exactly this, so a share whose deadline has passed
  /// is still recognisably a *live* share that ended, not a static one.
  final DateTime? liveExpiresAt;

  /// When the position was last written. Drives the "updated N minutes ago"
  /// affordance and [isStaleAt].
  final DateTime? liveUpdatedAt;

  /// Set once the share has ended, by whichever of the three routes got there
  /// first: the sharer stopping it, the server's scheduled expiry, or the repair
  /// sweep. Null on a running share and on a static one.
  final DateTime? liveEndedAt;

  bool get isLive => liveExpiresAt != null;

  /// Where this share stands at [now].
  ///
  /// The `now >= liveExpiresAt` clause is the load-bearing one, and it is why
  /// this is computed rather than read off a stored flag. A share expires while
  /// somebody is looking at it: the server patches the row a moment later, but
  /// the bubble must go grey on the tick the deadline passes, not when the
  /// round trip completes. Reading a server flag would leave a bubble saying
  /// "live until 14:30" at 14:31.
  ///
  /// It also covers the harder case — the server's scheduled expiry never fires
  /// at all (deployment restart, lost job). The row keeps `liveShareLive: true`
  /// until the six-hourly sweep finds it, and every client still stops trusting
  /// it at exactly the right second, because the deadline is data rather than
  /// an event.
  LiveShareState stateAt(DateTime now) {
    final until = liveExpiresAt;
    if (until == null) return LiveShareState.fixed;
    if (liveEndedAt != null) return LiveShareState.ended;
    if (!now.isBefore(until)) return LiveShareState.ended;
    return LiveShareState.live;
  }

  /// Time left before the share stops on its own, floored at zero. Zero on a
  /// static share and on one that has already ended.
  Duration remainingAt(DateTime now) {
    final until = liveExpiresAt;
    if (until == null) return Duration.zero;
    if (stateAt(now) != LiveShareState.live) return Duration.zero;
    final left = until.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// The sharer's device has stopped reporting, even though the share is still
  /// within its window.
  ///
  /// Distinguishing this from "stationary" is the whole reason `liveUpdatedAt`
  /// exists. Standing still and being force-quit look identical on a map, and
  /// only one of them means the dot is a lie. The publisher re-sends an
  /// unchanged position every [kLiveHeartbeat] precisely so that silence is
  /// informative: three missed heartbeats is a device that is not talking to us.
  ///
  /// False on a share that is not currently live — an ended share is not stale,
  /// it is finished, and drawing both states at once would say neither.
  bool isStaleAt(DateTime now) {
    if (stateAt(now) != LiveShareState.live) return false;
    final last = liveUpdatedAt;
    if (last == null) return false;
    return now.difference(last) > kLiveStaleAfter;
  }

  /// How far this is from [other], in metres, by the haversine formula.
  ///
  /// Used by the publisher to decide whether a new fix is worth a write, and by
  /// nothing that draws. Haversine rather than a projected approximation because
  /// the inputs here are tens of metres apart and the cheap flat-earth version
  /// is worst exactly where it is used most: at high latitudes, where a degree
  /// of longitude is a fraction of a degree of latitude.
  double distanceMetersTo(double otherLat, double otherLng) =>
      haversineMeters(latitude, longitude, otherLat, otherLng);

  @override
  String toString() =>
      'LocationShare($latitude, $longitude, acc: $accuracyM, until: $liveExpiresAt)';
}

/// The coordinate pair as the bubble prints it, and as "copy" puts it on the
/// clipboard.
///
/// Five decimal places — about a metre at the equator. Six would be a
/// centimetre, which is a precision no consumer GPS has and which would make
/// the card read as a measurement rather than as a place; four would be eleven
/// metres, enough to land on the wrong side of a street.
///
/// Plain signed decimal rather than degrees-minutes-seconds or a hemisphere
/// suffix, because the string's real job is to be pasted somewhere: every maps
/// application, search box and mapping library accepts `41.01234, 28.97654`,
/// and a good many reject `41°00'44.4"N`.
String formatCoordinates(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

/// Great-circle distance between two WGS-84 points, in metres.
///
/// Free function as well as a method on [LocationShare] because the publisher
/// compares a brand-new fix against the last one it *sent*, and at that moment
/// neither is a share yet.
double haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusM = 6371000.0;
  double toRad(double d) => d * math.pi / 180.0;
  double sin2(double x) {
    final s = math.sin(x);
    return s * s;
  }

  final a = sin2(toRad(lat2 - lat1) / 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * sin2(toRad(lng2 - lng1) / 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(a).clamp(0.0, 1.0));
}

// ── Battery and freshness tuning ────────────────────────────────────────────
//
// These four numbers are the entire battery story of live sharing, so they are
// stated together with what each one buys.

/// Only ask the OS to wake us when the sharer has moved this far.
///
/// A distance filter and not a timer, because that is the setting that actually
/// costs battery: with one, a phone on a desk is a phone whose GPS is idle, and
/// no amount of interval tuning achieves that. 25 m is below the width of a city
/// block, so a dot following a walk still visibly follows it, and well above the
/// jitter of a stationary consumer GPS fix (typically 5–15 m), so a phone that
/// is not moving does not generate a stream of updates saying so.
const double kLiveDistanceFilterMeters = 25;

/// Never publish two positions closer together than this, however fast the
/// sharer is moving.
///
/// The filter above is a distance, so speed sets the rate: at 100 km/h a 25 m
/// filter fires roughly once a second. This is the ceiling that turns that into
/// six writes a minute instead of sixty — the difference between a live share
/// and a denial-of-service on one message row. Mirrored, more loosely, by
/// `LIVE_UPDATE_MIN_INTERVAL_MS` server-side.
const Duration kLiveMinPublishInterval = Duration(seconds: 10);

/// Re-publish an unchanged position at least this often.
///
/// Costs one small mutation every ninety seconds — for the longest share
/// offered, 320 writes over eight hours — and buys the single thing a map
/// cannot show on its own: the difference between "they have stopped walking"
/// and "their phone has stopped talking to us". Without it a viewer watching a
/// stationary dot has no way to tell which, and the honest reading of an
/// unchanging dot would have to be "unknown", which is useless.
const Duration kLiveHeartbeat = Duration(seconds: 90);

/// Treat a live share as stale once it has been silent for this long.
///
/// Three missed heartbeats. Two would fire on one dropped mutation over bad
/// cellular, which is a normal event and not worth telling the viewer about;
/// four takes six minutes to notice a phone that died, which is too long to be
/// useful in the case where somebody is watching for a reason.
const Duration kLiveStaleAfter = Duration(minutes: 4, seconds: 30);
