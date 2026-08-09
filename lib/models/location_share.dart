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
// These numbers are the entire battery story of live sharing, so they are
// stated together with what each one buys. The four below are the FOREGROUND
// baseline; [LiveLocationMode] holds the background settings and says what it
// trades away.

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
///
/// Deliberately the SAME in every [LiveLocationMode]. The viewer has no idea
/// whether the sharer's app is on screen, and a staleness threshold that
/// quietly relaxed when the sharer pocketed their phone would mean the bubble's
/// one honest signal changed meaning without anybody being told. That is why
/// [kLiveHeartbeat] is also constant across modes — see [LiveLocationMode].
const Duration kLiveStaleAfter = Duration(minutes: 4, seconds: 30);

/// How precisely the publisher is asking the OS to measure.
///
/// Two values rather than the plugin's six, and named for what they cost rather
/// than for a metre count, because the number is a hint on both platforms and
/// the honest distinction is binary: [fine] is the one that needs the GPS
/// receiver powered, [coarse] is the one the OS can answer from cell towers and
/// Wi-Fi it was already listening to. Everything between those two is the same
/// decision with a different rounding.
///
/// Lives here rather than in `location_service.dart` so the publisher — and its
/// tests — can reason about power without `geolocator` in scope, which is the
/// same rule [LocationFix] follows.
enum LocationPrecision {
  /// GPS-grade, ~10 m. What a dot following somebody down a street needs.
  fine,

  /// Network-grade, ~100 m. Enough to say which neighbourhood, at roughly a
  /// tenth of the power.
  coarse,
}

/// How hard the publisher works, and what it gives up to work less.
///
/// Three settings rather than a foreground/background boolean, because
/// "backgrounded" is not one state. Thirty seconds in a pocket while its owner
/// checks the time and two hours in a pocket on a train are the same
/// `AppLifecycleState` and completely different power budgets, and a single
/// background setting has to be tuned for the worse of the two — which makes it
/// wrong for the common one.
///
/// What each mode changes and what it does NOT:
///
/// | | filter | interval | precision | heartbeat |
/// |---|---|---|---|---|
/// | [foreground] | 25 m | 10 s | fine | 90 s |
/// | [background] | 100 m | 30 s | fine | 90 s |
/// | [deepBackground] | 250 m | 60 s | coarse | 90 s |
///
/// The heartbeat column is the point of the table. Only the *cost* knobs move;
/// the freshness contract does not, so a viewer's STALE badge means exactly the
/// same thing in all three. See [kLiveStaleAfter].
///
/// The filter is the knob that matters. It is what the OS itself enforces, so
/// at 100 m a walking phone wakes this app roughly a quarter as often as at
/// 25 m — the interval ceiling only ever throws away work already done. The
/// cost is resolution: a dot that used to follow a street now cuts its corners.
/// That is the right trade for a screen nobody is looking at, and it is undone
/// the instant the app comes back.
enum LiveLocationMode {
  /// The app is on screen. The existing baseline, unchanged.
  foreground(
    distanceFilterMeters: kLiveDistanceFilterMeters,
    minPublishInterval: kLiveMinPublishInterval,
    precision: LocationPrecision.fine,
  ),

  /// The app is backgrounded but the process is alive and publishing —
  /// iOS's `location` background mode, or Android's foreground service.
  ///
  /// Still fine precision: the first minutes after a backgrounding are exactly
  /// when somebody is most likely to be walking somewhere and being followed,
  /// and dropping to coarse immediately would make the handoff from foreground
  /// visible as a 100 m jump.
  background(
    distanceFilterMeters: 100,
    minPublishInterval: Duration(seconds: 30),
    precision: LocationPrecision.fine,
  ),

  /// Backgrounded for [kLiveDeepBackgroundAfter] without coming back.
  ///
  /// This is the eight-hour share that has become the phone's background load
  /// for the afternoon, and the only mode that gives up accuracy. A coarse fix
  /// arrives with a coarse `accuracyM`, so the bubble draws a 100 m ring rather
  /// than pretending to a precision it no longer has — which is why this is an
  /// acceptable degradation and simply publishing less often is not: silence
  /// reads as a dead phone, a wide ring reads as a wide ring.
  deepBackground(
    distanceFilterMeters: 250,
    minPublishInterval: Duration(seconds: 60),
    precision: LocationPrecision.coarse,
  );

  const LiveLocationMode({
    required this.distanceFilterMeters,
    required this.minPublishInterval,
    required this.precision,
  });

  /// Movement the OS must observe before it wakes this app at all.
  final double distanceFilterMeters;

  /// Floor on the gap between two published positions, whatever the OS sends.
  final Duration minPublishInterval;

  /// How much radio the fixes are allowed to cost.
  final LocationPrecision precision;

  bool get isBackground => this != LiveLocationMode.foreground;
}

/// The words on the notification that says a share is running.
///
/// Carried as data rather than looked up where it is used, because the two
/// places that need it are both places with no `BuildContext`: Android's
/// foreground service, and the boot receiver that restarts it before there is a
/// Dart isolate to ask. Both read it back out of `LiveShareResumeStore`, which
/// is why it is persisted alongside the handle rather than rebuilt.
///
/// A pleasant side effect of persisting it: the notification stays in the
/// language the share was started in, rather than flipping to whatever the
/// device locale says after a reboot.
class LiveShareNotice {
  const LiveShareNotice({
    required this.title,
    required this.body,
    required this.stopLabel,
  });

  /// One line, e.g. "Sharing your live location".
  final String title;

  /// The second line — where, and until when.
  final String body;

  /// The action button. This is the requirement the whole notification exists
  /// for: a background tracker that can only be stopped by finding the app,
  /// opening it, finding the room and finding the bubble is the thing people are
  /// right to distrust.
  final String stopLabel;
}

/// How long the app must stay backgrounded before [LiveLocationMode.background]
/// gives way to [LiveLocationMode.deepBackground].
///
/// Twenty minutes, chosen from the shape of the two shares this feature has.
/// A fifteen-minute "I'm nearly there" share never reaches it, so the case
/// where fine resolution is the entire point keeps fine resolution for its
/// whole life. An eight-hour share crosses it once, early, and then runs cheap
/// for the remaining seven and a half hours. An hour-long share spends the
/// first third precise and the rest coarse, which matches how those are
/// actually watched — closely at the start, glanced at later.
///
/// Reset by any return to the foreground, not accumulated: coming back to the
/// app is the user saying the share still matters.
const Duration kLiveDeepBackgroundAfter = Duration(minutes: 20);
