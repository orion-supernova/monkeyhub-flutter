import 'dart:async';

import '../models/location_share.dart';
import 'live_location_platform.dart';
import 'live_share_resume_store.dart';
import 'location_service.dart';

/// Feeds one running live share, and only one.
///
/// ## What "background" means here, per platform
///
/// This used to be foreground-only. It is not any more, and the honest summary
/// of what each platform now gives is worth stating up front, because the two
/// are not the same feature and neither is "it just keeps working".
///
/// **Backgrounded app — both platforms, on When-In-Use.** The share keeps
/// publishing continuously when the app leaves the screen. On iOS that is
/// `UIBackgroundModes: location` plus `allowsBackgroundLocationUpdates`; on
/// Android it is a `foregroundServiceType="location"` service started while the
/// app was still on screen, which is what makes it legal without
/// `ACCESS_BACKGROUND_LOCATION`. Neither needs Always, and both are visible:
/// iOS draws the blue pill, Android shows a notification with a STOP button.
///
/// **Terminated app — iOS with Always.** `startMonitoringSignificantLocationChanges`
/// relaunches a killed app when the device moves roughly 500 m, at intervals
/// measured in minutes. That is the whole of what iOS offers and it is not
/// continuous tracking; between callbacks the share reads STALE on every
/// viewer's screen, which is correct, because between callbacks nobody knows
/// where this phone is.
///
/// **Terminated app — Android with a boot receiver.** The share is restarted
/// after a reboot, and after a swipe-away on stock Android. It is NOT restarted
/// on OEM builds that kill background services outright — Xiaomi, Huawei,
/// Samsung's aggressive power modes — and there is no API that makes them. This
/// is documented rather than fixed because it cannot be fixed.
///
/// **What holds in every one of those cases**: the share still ends on time. The
/// deadline is enforced server-side by a scheduled job, by the six-hourly repair
/// sweep and by `updateLiveLocation` refusing a late write, none of which depend
/// on this class ever running again. And a share this object has stopped feeding
/// goes STALE on every viewer's screen within [kLiveStaleAfter] rather than
/// showing a confidently wrong dot.
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
///
/// The heartbeat's cadence is the one number that does NOT change when the app
/// backgrounds. See [LiveLocationMode] for what does, and why.
class LiveLocationPublisher {
  LiveLocationPublisher({
    LocationService? service,
    LiveShareResumeStore? store,
    LiveLocationPlatform? platform,
    DateTime Function()? clock,
  })  : _service = service ?? LocationService.instance,
        _store = store ?? LiveShareResumeStore.instance,
        _platform = platform ?? LiveLocationPlatform.instance,
        _now = clock ?? DateTime.now;

  final LocationService _service;
  final LiveShareResumeStore _store;
  final LiveLocationPlatform _platform;
  final DateTime Function() _now;

  StreamSubscription<LocationFix>? _sub;
  Timer? _heartbeat;

  /// Fires once when the app has been backgrounded long enough to stop paying
  /// for fine precision. Cancelled by any return to the foreground — see
  /// [kLiveDeepBackgroundAfter].
  Timer? _deepBackgroundTimer;

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

  LiveLocationMode _mode = LiveLocationMode.foreground;

  /// How hard this is currently working. See [LiveLocationMode].
  LiveLocationMode get mode => _mode;

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
  ///
  /// [notice] is the copy for the persistent notification, and is persisted with
  /// the handle rather than looked up later — see [LiveShareNotice].
  ///
  /// Synchronous, and deliberately so. Every field [stop] clears, it clears
  /// before returning, so there is nothing here worth waiting for — and a
  /// version that awaited the old subscription's cancellation would leave the
  /// new share unstarted for as long as that took, with the fix that started it
  /// already going stale. The disk write and the platform call it fires are
  /// unawaited for the same reason: neither is a precondition for publishing,
  /// and both would put a channel round trip between the user's tap and the
  /// first position.
  void start({
    required String messageId,
    required String roomId,
    required DateTime expiresAt,
    required LocationFix firstFix,
    required LiveShareNotice notice,
    required Future<bool> Function(LocationFix fix) publish,
    void Function()? onEnded,
    bool monitorSignificantChanges = false,
  }) {
    // Not awaited: the state teardown inside is synchronous, and only the
    // stream cancellation is not. See [stop].
    stop();

    _begin(
      messageId: messageId,
      roomId: roomId,
      expiresAt: expiresAt,
      notice: notice,
      publish: publish,
      onEnded: onEnded,
      monitorSignificantChanges: monitorSignificantChanges,
      // Recorded as published without a round trip: `send` wrote exactly this
      // position onto the row, so re-sending it would be a redundant write, and
      // treating it as unpublished would make the first real movement look like
      // it had come from nowhere.
      alreadyPublished: firstFix,
    );
  }

  /// Picks a share back up in a process that did not start it.
  ///
  /// The three cases this covers, in increasing order of how little the user
  /// did: the app was force-quit and reopened; iOS relaunched us in the
  /// background because the device moved 500 m; Android's boot receiver
  /// restarted the service after a reboot.
  ///
  /// Differs from [start] in exactly one way, and it is the important one: there
  /// is no already-published position, so [_lastPublishedAt] starts null and the
  /// very first fix — from the stream or from the immediate heartbeat below —
  /// publishes without waiting out an interval ceiling. That is deliberate. The
  /// share has by definition been silent for as long as the process was gone,
  /// and is almost certainly reading STALE to everybody watching it; making it
  /// wait another thirty seconds to prove otherwise would be optimising the one
  /// moment where latency actually costs something.
  ///
  /// The caller is responsible for having checked [LiveShareHandle.isResumableAt]
  /// — but this checks the deadline again anyway, because between the store read
  /// and here is an await, and an eight-hour share can expire in an await if the
  /// device was asleep for the last of it.
  void resume({
    required LiveShareHandle handle,
    required Future<bool> Function(LocationFix fix) publish,
    void Function()? onEnded,
    bool monitorSignificantChanges = false,
  }) {
    stop();
    if (!handle.isResumableAt(_now())) return;

    _begin(
      messageId: handle.messageId,
      roomId: handle.roomId,
      expiresAt: handle.expiresAt,
      notice: handle.notice,
      publish: publish,
      onEnded: onEnded,
      monitorSignificantChanges: monitorSignificantChanges,
      alreadyPublished: null,
    );

    // Do not wait up to ninety seconds to say we are alive again. Unawaited
    // because [resume] is synchronous for the same reason [start] is.
    unawaited(_beat());
  }

  /// The shared body of [start] and [resume].
  void _begin({
    required String messageId,
    required String roomId,
    required DateTime expiresAt,
    required LiveShareNotice notice,
    required Future<bool> Function(LocationFix fix) publish,
    required void Function()? onEnded,
    required bool monitorSignificantChanges,
    required LocationFix? alreadyPublished,
  }) {
    _messageId = messageId;
    _roomId = roomId;
    _expiresAt = expiresAt;
    _publish = publish;
    _onEnded = onEnded;
    _lastPublished = alreadyPublished;
    _lastPublishedAt = alreadyPublished == null ? null : _now();

    // Written before the first fix, not after. The window this closes is small
    // and real: a phone killed by the OS four seconds into an eight-hour share
    // would otherwise come back with nothing to resume, and the share would sit
    // at its opening position until its deadline.
    unawaited(_store.save(LiveShareHandle(
      messageId: messageId,
      roomId: roomId,
      expiresAt: expiresAt,
      notice: notice,
    )));

    unawaited(_platform.startSharing(
      messageId: messageId,
      roomId: roomId,
      expiresAtMs: expiresAt.millisecondsSinceEpoch,
      notificationTitle: notice.title,
      notificationBody: notice.body,
      stopActionLabel: notice.stopLabel,
      monitorSignificantChanges: monitorSignificantChanges,
    ));

    _listen();
    _heartbeat = Timer.periodic(kLiveHeartbeat, (_) => _beat());
  }

  /// Opens (or re-opens) the position stream at the current [_mode].
  ///
  /// Separate from [_begin] because a mode change has to rebuild it: neither
  /// platform lets a running location request change its distance filter or its
  /// desired accuracy, so "turn the filter up" is spelled "cancel and ask
  /// again". The cancellation is unawaited and the new subscription is installed
  /// immediately — a gap here is a gap in the share.
  void _listen() {
    final old = _sub;
    _sub = _service.fixStream(mode: _mode).listen(
          _onFix,
          // A stream that errors — permission revoked mid-share, hardware gone —
          // is a stream that will not recover. Ending here rather than
          // swallowing it means the sharer's own bubble stops claiming to be
          // publishing, and the share is still ended on time by the server
          // either way.
          //
          // The persisted handle is deliberately KEPT: a permission the user
          // re-grants, or a relaunch that gets the hardware back, should pick
          // the share up again if it is still within its deadline.
          onError: (_) => stop(),
          cancelOnError: true,
        );
    unawaited(old?.cancel() ?? Future<void>.value());
  }

  /// Stops feeding, without ending the share.
  ///
  /// Ending a share is a server call — see `ChatRepository.stopLiveLocation` —
  /// and is deliberately not done here. This object may be torn down for
  /// reasons that are none of the share's business (the room screen closing,
  /// the app shutting down), and a teardown that silently ended the user's
  /// share would make walking out of a chat a way to stop being findable
  /// without meaning to.
  ///
  /// [forget] draws the line between the two kinds of stop, and getting it
  /// wrong is the bug that breaks resume in one direction and creates zombie
  /// shares in the other:
  ///
  ///  * false (default) — this PROCESS is stopping. The persisted handle stays,
  ///    so the next launch picks the share back up. Used for stream errors and
  ///    for a share being superseded.
  ///  * true — this SHARE is over: the deadline passed, the server refused an
  ///    update, the user pressed stop, the account signed out. The handle goes,
  ///    so nothing ever resumes it.
  ///
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
  Future<void> stop({bool forget = false}) {
    final wasRunning = isRunning;
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

    // [_mode] and [_deepBackgroundTimer] are deliberately LEFT ALONE. They
    // describe where the app is, not what the share is doing, and resetting
    // them here would make stopping a share look like the user coming back to
    // the screen — so the next share, started or resumed from a process that is
    // still in the background, would open its position stream at foreground
    // settings and spend the battery this whole mechanism exists to save.
    // [setAppVisible] owns both, and is the only thing that should touch them.

    // Guarded on `wasRunning` only for the platform call, not for the forget:
    // [stop] is called speculatively (from the front of [start], from sign-out)
    // and asking the platform to tear down a service that was never started is a
    // channel hop for nothing, whereas clearing a handle that may have outlived
    // its publisher is the entire point of `forget`.
    if (wasRunning) unawaited(_platform.stopSharing());
    if (forget) unawaited(_store.clear());

    if (ended != null) ended();
    return sub?.cancel() ?? Future<void>.value();
  }

  /// Tells the publisher whether the app is on screen.
  ///
  /// Driven from the app's single lifecycle observer rather than from the room
  /// screen, because the share outlives the screen: walking out of a chat does
  /// not stop a share, and a publisher whose power tier was tied to a widget's
  /// mount state would drop to background settings when the user opened their
  /// own profile.
  ///
  /// `inactive` counts as visible, matching the rest of this app's lifecycle
  /// handling. iOS fires it for every Control Centre swipe and app-switcher
  /// peek, and re-opening the position stream twice for each of those would cost
  /// more than the settings ever save.
  void setAppVisible(bool visible) {
    _deepBackgroundTimer?.cancel();
    _deepBackgroundTimer = null;
    if (visible) {
      _applyMode(LiveLocationMode.foreground);
      return;
    }
    _applyMode(LiveLocationMode.background);
    // One-shot, and re-armed from scratch on the next backgrounding rather than
    // accumulated. Coming back to the app is the user saying the share still
    // matters; twenty minutes away is twenty minutes away, whether or not they
    // were away for nineteen an hour ago.
    _deepBackgroundTimer = Timer(
      kLiveDeepBackgroundAfter,
      () => _applyMode(LiveLocationMode.deepBackground),
    );
  }

  void _applyMode(LiveLocationMode next) {
    if (_mode == next) return;
    _mode = next;
    // Nothing to rebuild if no share is running. The mode is still recorded, so
    // a share started while backgrounded — which a resume in a background launch
    // is — opens at the right settings rather than at foreground ones.
    if (!isRunning) return;
    _listen();
  }

  Future<void> _onFix(LocationFix fix) async {
    if (!isRunning) return;
    if (_isPastDeadline()) {
      await stop(forget: true);
      return;
    }
    final since = _lastPublishedAt;
    // The interval ceiling. The OS filter bounds updates by distance, so speed
    // sets the rate — at motorway speed a 25 m filter fires about once a second
    // — and without this a drive would be hundreds of writes to one row. The
    // ceiling rises with the mode; see [LiveLocationMode].
    if (since != null && _now().difference(since) < _mode.minPublishInterval) {
      return;
    }
    await _send(fix);
  }

  Future<void> _beat() async {
    if (!isRunning) return;
    if (_isPastDeadline()) {
      await stop(forget: true);
      return;
    }
    // A fresh reading, not the cached one. See the class comment — this is what
    // makes `liveUpdatedAt` mean "we knew this at that moment" rather than "we
    // were still running at that moment".
    //
    // At [LiveLocationMode.deepBackground] the reading is deliberately coarse.
    // It arrives with a coarse `accuracyM`, which travels to the bubble and is
    // drawn as a wider ring — so the card says "somewhere in this circle",
    // which is true, rather than pretending to a precision the app stopped
    // paying for.
    final fix = await _service.currentFix(
      timeout: const Duration(seconds: 10),
      precision: _mode.precision,
    );
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
      // from another device, or the message deleted. Stop rather than retry,
      // and forget it: there is nothing left for a future launch to resume.
      await stop(forget: true);
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
