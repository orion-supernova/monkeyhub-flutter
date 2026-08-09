import 'dart:async';

import '../models/location_share.dart';
import 'location_service.dart';

/// Feeds one running live share, and only one.
///
/// ## Foreground only, and what that costs
///
/// This app asks for WHEN IN USE location and declares no background location
/// capability: no `UIBackgroundModes` entry containing `location` on iOS, no
/// `FOREGROUND_SERVICE_LOCATION` service on Android. So a live share updates
/// while the app is on screen and goes quiet when it is not.
///
/// That is a smaller feature than the one the large messengers ship, and it is
/// chosen rather than settled for:
///
///  * On iOS, background location requires `Always` authorisation. The user is
///    then shown a system alert every so often reminding them the app has been
///    using their location in the background — an alert that arrives with no
///    context, days after the share ended — and App Review asks the developer
///    to justify continuous background access for a chat app. The honest
///    justification is "one optional feature, for a few hours at a time", which
///    is exactly the case Apple pushes back on.
///  * On Android it means a foreground service with a permanent notification
///    plus a Play Console background-location declaration and a demo video.
///
/// The consequence is visible rather than hidden, which is the part that makes
/// it acceptable: a share whose publisher has stopped goes STALE on every
/// viewer's screen within [kLiveStaleAfter], and the bubble says so. A viewer
/// is never shown a confidently wrong dot. The share still ends on time
/// regardless, because the deadline is enforced server-side and does not depend
/// on this class existing.
///
/// Reversing the decision is contained: grant `Always`, add the platform
/// declarations, and pass `AppleSettings(allowBackgroundLocationUpdates: true)`
/// / `AndroidSettings(foregroundNotificationConfig: ...)` in
/// [LocationService.fixStream]. Nothing above this file would change.
///
/// ## The heartbeat, and why it re-measures
///
/// Position updates are driven by a distance filter, so a phone that is not
/// moving produces no updates at all — which is indistinguishable, to a viewer,
/// from a phone that has been switched off. [kLiveHeartbeat] closes that by
/// publishing on a timer as well.
///
/// It takes a NEW fix rather than re-sending the last one, and that is the
/// whole point of it. Re-publishing a cached position with a fresh
/// `liveUpdatedAt` would tell every viewer "this is where they are now" on the
/// strength of a reading that could be an hour old — the one thing a live share
/// must never do. Asking the OS for a current fix costs one query every ninety
/// seconds and makes the freshness stamp mean what it says.
class LiveLocationPublisher {
  LiveLocationPublisher({
    LocationService? service,
    DateTime Function()? clock,
  })  : _service = service ?? LocationService.instance,
        _now = clock ?? DateTime.now;

  final LocationService _service;
  final DateTime Function() _now;

  StreamSubscription<LocationFix>? _sub;
  Timer? _heartbeat;

  /// The share being fed, or null when nothing is running.
  String? _messageId;

  /// The room the running share lives in. Held so a caller can ask "am I
  /// sharing in this room?" without tracking it separately.
  String? _roomId;

  /// The deadline, so this can shut itself down at the same moment the server
  /// does rather than being told.
  DateTime? _expiresAt;

  /// The last position actually sent, and when it was sent. Together these are
  /// the throttle: a new fix has to clear both the distance the OS filter let
  /// through and the interval below.
  LocationFix? _lastPublished;
  DateTime? _lastPublishedAt;

  Future<bool> Function(LocationFix fix)? _publish;
  void Function()? _onEnded;

  String? get activeMessageId => _messageId;
  String? get activeRoomId => _roomId;
  bool get isRunning => _messageId != null;

  bool isRunningFor(String messageId) => _messageId == messageId;

  /// Starts feeding [messageId].
  ///
  /// Stops any share already running first. One publisher and one share is a
  /// deliberate limit rather than a simplification: two concurrent shares mean
  /// two GPS consumers and two write streams for a user who can only be in one
  /// place, and the server enforces the same rule from the other side by ending
  /// a sender's previous share in a room when a new one starts.
  ///
  /// [publish] returns whether the share is still live as far as the server is
  /// concerned. A false answer stops everything — that is how a share ended
  /// from another device, or ended by the server's own deadline, reaches this
  /// object without polling for it.
  ///
  /// [firstFix] is the position already obtained to create the message. Passed
  /// in rather than re-measured because the send path has just spent up to
  /// fifteen seconds getting one, and asking again would put a second GPS
  /// query, and a second few seconds, between the user tapping share and
  /// anything happening.
  /// Synchronous, and deliberately so. Every field [stop] clears, it clears
  /// before returning, so there is nothing here worth waiting for — and a
  /// version that awaited the old subscription's cancellation would leave the
  /// new share unstarted for as long as that took, with the fix that started it
  /// already going stale.
  void start({
    required String messageId,
    required String roomId,
    required DateTime expiresAt,
    required LocationFix firstFix,
    required Future<bool> Function(LocationFix fix) publish,
    void Function()? onEnded,
  }) {
    // Not awaited: the state teardown inside is synchronous, and only the
    // stream cancellation is not. See [stop].
    stop();

    _messageId = messageId;
    _roomId = roomId;
    _expiresAt = expiresAt;
    _publish = publish;
    _onEnded = onEnded;
    // Recorded as published without a round trip: `send` wrote exactly this
    // position onto the row, so re-sending it would be a redundant write, and
    // treating it as unpublished would make the first real movement look like
    // it had come from nowhere.
    _lastPublished = firstFix;
    _lastPublishedAt = _now();

    _sub = _service.fixStream().listen(
      _onFix,
      // A stream that errors — permission revoked mid-share, hardware gone — is
      // a stream that will not recover. Ending here rather than swallowing it
      // means the sharer's own bubble stops claiming to be publishing, and the
      // share is still ended on time by the server either way.
      onError: (_) => stop(),
      cancelOnError: true,
    );

    _heartbeat = Timer.periodic(kLiveHeartbeat, (_) => _beat());
  }

  /// Stops feeding, without ending the share.
  ///
  /// Ending a share is a server call — see `ChatRepository.stopLiveLocation` —
  /// and is deliberately not done here. This object may be torn down for
  /// reasons that are none of the share's business (the room screen closing,
  /// the app shutting down), and a teardown that silently ended the user's
  /// share would make walking out of a chat a way to stop being findable
  /// without meaning to.
  /// Every field is cleared SYNCHRONOUSLY, before the returned future is
  /// awaited by anybody. That matters more than it looks: this is called from
  /// inside the stream's own handler (a fix past the deadline) and from the
  /// front of [start] (a second share superseding the first), so a version that
  /// tore down after an await would leave a window in which [isRunning] is
  /// still true for a publisher that is on its way out — and a fix arriving in
  /// that window would be published to a share nobody is feeding any more.
  ///
  /// Only the subscription's cancellation is asynchronous, and it is simply
  /// handed back. Nothing depends on it having finished; the handler already
  /// returns early once the state above is gone.
  Future<void> stop() {
    _heartbeat?.cancel();
    _heartbeat = null;
    final sub = _sub;
    _sub = null;
    final ended = _onEnded;
    _messageId = null;
    _roomId = null;
    _expiresAt = null;
    _publish = null;
    _onEnded = null;
    _lastPublished = null;
    _lastPublishedAt = null;
    if (ended != null) ended();
    return sub?.cancel() ?? Future<void>.value();
  }

  Future<void> _onFix(LocationFix fix) async {
    if (!isRunning) return;
    if (_isPastDeadline()) {
      await stop();
      return;
    }
    final since = _lastPublishedAt;
    // The interval ceiling. The OS filter bounds updates by distance, so speed
    // sets the rate — at motorway speed a 25 m filter fires about once a second
    // — and without this a drive would be hundreds of writes to one row.
    if (since != null && _now().difference(since) < kLiveMinPublishInterval) {
      return;
    }
    await _send(fix);
  }

  Future<void> _beat() async {
    if (!isRunning) return;
    if (_isPastDeadline()) {
      await stop();
      return;
    }
    // A fresh reading, not the cached one. See the class comment — this is what
    // makes `liveUpdatedAt` mean "we knew this at that moment" rather than "we
    // were still running at that moment".
    final fix = await _service.currentFix(timeout: const Duration(seconds: 10));
    // No fix, no publish. Silence is the correct signal: viewers see the share
    // go stale, which is exactly what has happened.
    if (fix == null || !isRunning) return;
    await _send(fix);
  }

  Future<void> _send(LocationFix fix) async {
    final publish = _publish;
    if (publish == null) return;
    final ok = await publish(fix);
    if (!ok) {
      // The server says this share is over — expired on its deadline, stopped
      // from another device, or the message deleted. Stop rather than retry.
      await stop();
      return;
    }
    _lastPublished = fix;
    _lastPublishedAt = _now();
  }

  bool _isPastDeadline() {
    final until = _expiresAt;
    return until != null && !_now().isBefore(until);
  }

  /// How far the sharer has moved since the last published position, or null
  /// when nothing has been published yet. Exposed for the sender's own UI, and
  /// for tests; the publish decision itself is made above.
  double? metersSinceLastPublish(LocationFix fix) =>
      _lastPublished == null ? null : fix.distanceMetersTo(_lastPublished!);
}
