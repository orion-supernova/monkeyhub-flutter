import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_share.dart';

/// The few facts a cold process needs to pick a live share back up.
///
/// Everything else about a share — its position history, who can see it, when
/// it was last written — lives on the server row and is re-read from there. This
/// is only the identity, the deadline and the notification copy: the minimum a
/// publisher needs to start feeding the right message, to know when to stop, and
/// to put a stoppable notification on screen before it has asked anybody
/// anything.
class LiveShareHandle {
  const LiveShareHandle({
    required this.messageId,
    required this.roomId,
    required this.expiresAt,
    required this.notice,
  });

  /// The SERVER's message id, never an optimistic `tmp_` one. A publisher
  /// patches this exact row; an optimistic id patches nothing, which is why
  /// `ChatRepository.startLiveLocation` only persists a handle once the send is
  /// acked.
  final String messageId;

  final String roomId;

  /// When the share stops on its own. The reason this is stored rather than
  /// re-derived: after a reboot there is no other local evidence that the share
  /// is over, and asking the server first would mean waking the network on every
  /// launch for a share that expired last Tuesday.
  final DateTime expiresAt;

  /// What the persistent notification says. See [LiveShareNotice] for why this
  /// travels with the handle instead of being looked up.
  final LiveShareNotice notice;

  /// Whether resuming this share would still be publishing into something live.
  ///
  /// A local pre-check, not the authority. The server re-decides on the first
  /// mutation and can say no for reasons this device cannot see — the share was
  /// stopped from another handset, the message was deleted, the sender lost
  /// write access to the room. The point of checking here is to avoid waking the
  /// GPS and the socket for a share that is *obviously* finished.
  bool isResumableAt(DateTime now) => now.isBefore(expiresAt);

  @override
  String toString() => 'LiveShareHandle($messageId in $roomId until $expiresAt)';
}

/// Where a running live share is written down so it can outlive the process.
///
/// ## Why `SharedPreferences` and not the secure store
///
/// `SessionStore` puts the user id in the Keychain, and the obvious instinct is
/// to keep the share beside it. Two reasons not to:
///
///  * A message id and a room id are not credentials. They are useless without
///    the session, which *is* in the Keychain and stays there.
///  * `SharedPreferences` on Android is a plain XML file that Kotlin can read
///    directly, and that is load-bearing rather than convenient. The boot
///    receiver has to answer "is there a share worth restarting?" before it
///    starts a foreground service, which is before there is a Dart isolate to
///    ask. Reading three keys off disk costs a millisecond; booting a Flutter
///    engine to discover the answer is no costs seconds and a notification the
///    user did not need to see.
///
/// The three keys are therefore a cross-language contract. Android's
/// `LiveLocationBootReceiver` reads them under the `flutter.` prefix that the
/// `shared_preferences` legacy API adds on that platform — `flutter.mh.liveShare.
/// messageId` and friends. Renaming one here breaks a file you are not looking
/// at; `test/live_share_resume_store_test.dart` pins the names.
///
/// ## What is deliberately not here
///
/// No position, and no "was publishing" flag. A resumed share publishes its
/// first fix from a fresh measurement, and until that lands the row still holds
/// whatever the last live position was — which will read as STALE to viewers
/// within [kLiveStaleAfter] and is exactly right, because between the process
/// dying and the process coming back nobody knew where this phone was.
class LiveShareResumeStore {
  LiveShareResumeStore();

  /// Injectable for tests, which swap in a fake rather than reaching for the
  /// platform channel. Matches the shape `LocationService.instance` uses.
  static LiveShareResumeStore instance = LiveShareResumeStore();

  static const kMessageIdKey = 'mh.liveShare.messageId';
  static const kRoomIdKey = 'mh.liveShare.roomId';
  static const kExpiresAtKey = 'mh.liveShare.expiresAt';
  static const kTitleKey = 'mh.liveShare.title';
  static const kBodyKey = 'mh.liveShare.body';
  static const kStopLabelKey = 'mh.liveShare.stopLabel';

  /// Sticky, per install: has this user ever been shown the "Always" explainer?
  ///
  /// Separate from the handle because it outlives every share. See
  /// [hasOfferedAlwaysUpgrade] for why it must never be cleared.
  static const kAlwaysOfferedKey = 'mh.liveShare.alwaysOffered';

  /// Every read and write goes through this, and every one of them tolerates
  /// the store not being there.
  ///
  /// `SharedPreferences.getInstance()` is a platform channel, and it is missing
  /// in three real situations: a unit-test host, a platform this app builds for
  /// but does not ship this feature on, and a background isolate whose plugin
  /// registrant has not finished. None of those is worth an exception, because
  /// of what depends on this class — the resume runs inside `attach`, which is
  /// sign-in. A live share that could not be written down is a share that stops
  /// when the process does, which is a whole permission tier this app already
  /// ships and describes honestly. A sign-in that throws is a user who cannot
  /// use the app.
  Future<SharedPreferences?> get _prefs async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Records the share this device is now feeding, replacing any previous one.
  ///
  /// Replacing rather than appending is the same one-share rule
  /// `LiveLocationPublisher` enforces in memory, and it has to be enforced here
  /// too: a second handle left on disk would have a rebooted device resume a
  /// share the user superseded hours ago.
  Future<void> save(LiveShareHandle handle) async {
    final prefs = await _prefs;
    if (prefs == null) return;
    await prefs.setString(kMessageIdKey, handle.messageId);
    await prefs.setString(kRoomIdKey, handle.roomId);
    await prefs.setString(kTitleKey, handle.notice.title);
    await prefs.setString(kBodyKey, handle.notice.body);
    await prefs.setString(kStopLabelKey, handle.notice.stopLabel);
    // Written last, and read first by [load]. If the process dies part-way
    // through, a handle missing its deadline is a handle [load] refuses, which
    // is the safe direction to fail in: no resume rather than a resume with no
    // stopping condition.
    await prefs.setInt(kExpiresAtKey, handle.expiresAt.millisecondsSinceEpoch);
  }

  /// The share this device was feeding when it last ran, if any.
  ///
  /// Returns null for a torn write (see [save]) as well as for no share at all;
  /// the two are indistinguishable from here and want the same treatment.
  Future<LiveShareHandle?> load() async {
    final prefs = await _prefs;
    if (prefs == null) return null;
    final expiresAtMs = prefs.getInt(kExpiresAtKey);
    if (expiresAtMs == null) return null;
    final messageId = prefs.getString(kMessageIdKey);
    final roomId = prefs.getString(kRoomIdKey);
    if (messageId == null || messageId.isEmpty) return null;
    if (roomId == null || roomId.isEmpty) return null;
    return LiveShareHandle(
      messageId: messageId,
      roomId: roomId,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
      // Defaulted rather than refused. Missing copy is a cosmetic problem — an
      // empty notification line — and refusing to resume a live share over it
      // would trade the feature for its label.
      notice: LiveShareNotice(
        title: prefs.getString(kTitleKey) ?? '',
        body: prefs.getString(kBodyKey) ?? '',
        stopLabel: prefs.getString(kStopLabelKey) ?? '',
      ),
    );
  }

  /// [load], but returns only a share that is still within its deadline, and
  /// erases one that is not.
  ///
  /// The erase is the reason this exists as its own method rather than as two
  /// calls at the call site. A handle for an expired share is litter that will
  /// be re-read on every launch forever, and every one of those reads is a
  /// chance for a bug elsewhere to act on it. Deleting it the first time we
  /// notice makes "there is a handle" mean "there is something to do".
  Future<LiveShareHandle?> takeResumable(DateTime now) async {
    final handle = await load();
    if (handle == null) return null;
    if (!handle.isResumableAt(now)) {
      await clear();
      return null;
    }
    return handle;
  }

  /// Forgets the running share. Called when one ends by any route — the user
  /// stopping it, the deadline passing, the server refusing an update.
  ///
  /// Does NOT touch [kAlwaysOfferedKey]: that describes the person, not the
  /// share.
  Future<void> clear() async {
    final prefs = await _prefs;
    if (prefs == null) return;
    // Deadline first, mirroring [save]'s "written last": whatever order these
    // interleave with a crash, the key [load] gates on is the first to go.
    await prefs.remove(kExpiresAtKey);
    await prefs.remove(kMessageIdKey);
    await prefs.remove(kRoomIdKey);
    await prefs.remove(kTitleKey);
    await prefs.remove(kBodyKey);
    await prefs.remove(kStopLabelKey);
  }

  /// Whether the "Always" explainer has already been shown once.
  ///
  /// This flag is the entire anti-nagging mechanism, and it is set when the
  /// sheet is SHOWN rather than when the permission is granted — deliberately.
  /// Keying it on the grant would mean every single live share re-asks a user
  /// who thought about it and said no, which is precisely the behaviour that
  /// makes people uninstall location apps. Asked once, answered, never again;
  /// the Settings app remains available to anybody who changes their mind.
  /// An unreadable store answers "not yet asked", which errs towards showing
  /// the sheet once too often rather than never — the opposite default would
  /// mean a user who can never discover the feature exists.
  Future<bool> hasOfferedAlwaysUpgrade() async {
    final prefs = await _prefs;
    return prefs?.getBool(kAlwaysOfferedKey) ?? false;
  }

  Future<void> markAlwaysUpgradeOffered() async {
    final prefs = await _prefs;
    if (prefs == null) return;
    await prefs.setBool(kAlwaysOfferedKey, true);
  }
}
