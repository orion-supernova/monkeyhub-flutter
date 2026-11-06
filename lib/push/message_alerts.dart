import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show VoidCallback, visibleForTesting;

import '../audio/alert_sounds.dart';
import '../l10n/app_labels.dart';
import '../platform.dart';
import '../data/chat_repository.dart';
import '../media/file_url_cache.dart';
import '../models/chat_room.dart';
import '../privacy/app_only.dart';
import 'alert_burst.dart';
import 'banner_composer.dart';
import 'linux_notifier.dart';
import 'push_manager.dart';
import 'viewer_presence.dart';
import 'web_notifier.dart';
import 'windows_notifier.dart';

/// Plays a sound (and, on web, shows a browser banner) when a new inbound
/// message arrives in a room the user isn't currently viewing.
///
/// Why this exists: on mobile, APNs/FCM deliver a banner with the OS
/// notification sound. Windows and Linux have no push at all, a FOREGROUND web
/// tab gets no Web Push banner either, and a Mac in front of its user has its
/// APNs banner suppressed on purpose (macos/Runner/AppDelegate.swift
/// `willPresent`), so without this new messages would arrive silently. This
/// observes the rooms-list subscription — which refires with an advanced
/// `lastMessageTime` on every new message — and fires an alert when a room's
/// newest message moves forward while the room `hasUnread` (i.e. it isn't the
/// user's own send) and isn't the room on screen.
///
/// Scope: web + desktop only. Mobile is served by the OS notification.
///
/// Linux and Windows also get a desktop banner per room from here
/// ([LinuxNotifier], [WindowsNotifier]), because nothing else can give them
/// one: they have no push service the app can use, so the socket this
/// observes is the only way a message reaches them. The banner is composed
/// like the phones' ([BannerComposer]): one per room, the last few lines, the
/// sender's face. While the window is in the background a burst from one room
/// pings once, not per line ([AlertBurst]); the rest update the banner
/// silently.
///
/// On a Mac with working push ([PushManager.osDeliversMessageAlerts]) the work
/// is split by whether anyone is looking: in front of the user this pings and
/// the OS stays silent; otherwise the OS banner (with its own sound) speaks and
/// this stays silent. Exactly one of the two, never both.
class MessageAlerts {
  MessageAlerts._();
  static final MessageAlerts instance = MessageAlerts._();

  /// Web (autoplay + Notification API) and desktop (no native push) need this;
  /// mobile is served by the OS notification the backend pushes directly
  /// (backend/convex/push.ts → APNs / FCM).
  static bool get _enabled => isWebOrDesktop;

  /// Replaces the sound under `flutter test`, so the alert rules can be
  /// asserted without an audio player.
  @visibleForTesting
  static VoidCallback? debugOnPing;

  /// Whether the person is chatting on ANOTHER of their devices right now —
  /// `engagement:engagedElsewhere` on the backend, installed by app.dart.
  ///
  /// Asked only while this window is not in front, just before an alert would
  /// fire: you are replying from your phone, so the Linux box and the browser
  /// tab have nothing to tell you. The push-driven platforms get the same rule
  /// from the server, which sends their notifications quiet (push.ts
  /// `AlertSpec.quiet`); this is the half for the alerts the app raises itself.
  ///
  /// Null means "never ask", which keeps alerts synchronous — the tests, and a
  /// build whose backend has no such function yet.
  Future<bool> Function()? engagedElsewhere;

  /// The last answer, reused for [_kEngagedFresh] so a burst asks once.
  ({DateTime at, bool value})? _engaged;
  static const _kEngagedFresh = Duration(seconds: 5);

  Future<bool> _isEngagedElsewhere(Future<bool> Function() ask) async {
    final hit = _engaged;
    final now = DateTime.now();
    if (hit != null && now.difference(hit.at) < _kEngagedFresh) {
      return hit.value;
    }
    bool value;
    try {
      value = await ask().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Unknown is "not engaged": a missed quiet is a chime too many, a
      // wrong one is a message nobody hears about.
      value = false;
    }
    _engaged = (at: DateTime.now(), value: value);
    return value;
  }

  ChatRepository? _repo;
  // roomId → newest message time we've already alerted on (ms since epoch).
  final Map<String, int> _lastSeen = {};

  void setOnOpenRoom(void Function(String roomId) cb) {
    WebNotifier.setOnOpenRoom(cb);
    for (final sink in _sinks) {
      sink.setOnOpenRoom(cb);
    }
  }

  final AlertBurst _burst = AlertBurst();
  final BannerComposer _composer = BannerComposer();

  /// The desktop platforms that draw a banner themselves (at most one is
  /// supported on any given build).
  static final List<DesktopBannerSink> _sinks = [
    LinuxNotifier.instance,
    WindowsNotifier.instance,
  ];

  static DesktopBannerSink? get _sink {
    for (final s in _sinks) {
      if (s.isSupported) return s;
    }
    return null;
  }

  void bind(ChatRepository repo) {
    if (!_enabled) return;
    if (identical(_repo, repo)) return;
    // Closing a banner by hand is reading it: the next line starts afresh.
    for (final sink in _sinks) {
      sink.setOnDismissed(_composer.reset);
    }
    _repo?.removeListener(_onChange);
    _repo = repo;
    // Establish a baseline of current room states so the initial room-list
    // delivery (which carries every room's existing last message) does not
    // alert for history. Only advances past this baseline fire.
    _lastSeen.clear();
    _snapshot(repo);
    repo.addListener(_onChange);
  }

  void unbind() {
    _repo?.removeListener(_onChange);
    _repo = null;
    _lastSeen.clear();
    _burst.clear();
    _composer.clear();
    _engaged = null;
  }

  int _msgTime(ChatRoom room) =>
      room.lastMessageTime?.millisecondsSinceEpoch ?? 0;

  void _snapshot(ChatRepository repo) {
    for (final r in repo.rooms) {
      _lastSeen[r.id] = _msgTime(r);
    }
  }

  /// Whether the user is actively looking at the app right now. On web this is
  /// real window focus (`document.hasFocus()`) — a visible-but-unfocused window
  /// counts as NOT focused; on desktop it's the Flutter lifecycle. Drives the
  /// alert rules below.
  ///
  /// Shared with [ChatRepository], which asks the same question to decide
  /// whether the open room's read cursor may advance. Deliberately one
  /// definition: a build where a message is quiet but still marked read is a
  /// message that vanishes without ever having been seen.
  bool get _focused => viewerIsPresent;

  void _onChange() {
    final repo = _repo;
    if (repo == null) return;
    final active = repo.activeRoomId;
    final focused = _focused;
    // Nobody is looking and the OS is already showing a banner with a sound
    // for this message: a ping on top would be the same alert twice.
    if (!focused && PushManager.instance.osDeliversMessageAlerts) {
      _snapshot(repo);
      return;
    }
    final me = repo.userId;
    // A desktop banner stands in for the push this build cannot receive, so
    // it follows the same rule the phones' banners do: only while nobody is
    // looking.
    final sink = _sink;
    final banners = sink != null && !focused;
    // Opening the room is reading it; its banner has nothing left to say, and
    // the lines it held must not come back with the next message.
    if (sink != null && focused && active != null) {
      if (_composer.current(active) != null) {
        _composer.reset(active);
        unawaited(sink.dismissRoom(active));
      }
    }
    // The room on screen is being read, so its burst is over: the next line
    // after you look away should be heard.
    if (focused && active != null) _burst.forget(active);
    final due = <ChatRoom>[];
    for (final r in repo.rooms) {
      final t = _msgTime(r);
      final prev = _lastSeen[r.id];
      _lastSeen[r.id] = t;
      // New room the baseline never saw: record it, don't alert (avoids a
      // burst when rooms first load).
      if (prev == null) continue;
      if (t <= prev) continue; // no newer message in this room

      // Alert rules:
      //  - The room you're viewing (`active`): alert ONLY when the app is not
      //    focused. When focused you see it live; and while unfocused you
      //    aren't the one sending, so the new message is the peer's. (Can't
      //    use hasUnread here — an open room is auto-marked-read.)
      //  - Any other room: alert when it has unread (a genuine inbound msg).
      //
      // A room whose notifications are muted never reaches either rule. This
      // ping is a notification — it is the in-app half of the same
      // interruption the backend is already suppressing at `push.sendAlert` —
      // and silencing the lock screen while the app keeps chiming would be the
      // most confusing possible half-measure. Note it is checked separately
      // from `hasUnread` below, which only knows about the OTHER switch: a
      // room muted down to its counts is silent here as a side effect, and a
      // room muted only for notifications would otherwise still ping.
      if (r.notificationsMuted) continue;
      // Your own message, sent from another device (or this one). It moves
      // `lastMessageTime` like anything inbound, and in the room on screen
      // nothing else would stop it: that branch can't consult `hasUnread`.
      if (r.isLastMessageFrom(me)) continue;
      final isActive = r.id == active;
      final shouldAlert = isActive ? !focused : r.hasUnread;
      if (shouldAlert) due.add(r);
    }
    if (due.isEmpty) return;

    // In front of the person, this IS the device in use; nothing to ask.
    final ask = focused ? null : engagedElsewhere;
    if (ask == null) {
      _fire(repo, due, banners: banners);
      return;
    }
    unawaited(() async {
      if (await _isEngagedElsewhere(ask)) return;
      // Signed out or rebound while the answer was on its way.
      if (!identical(_repo, repo)) return;
      _fire(repo, due, banners: banners);
    }());
  }

  void _fire(ChatRepository repo, List<ChatRoom> due, {required bool banners}) {
    var pinged = false;
    for (final r in due) {
      // Only the first line of a burst is heard; the rest update the banner
      // silently. On every surface, not just the desktop banners: a Mac or
      // Windows window in front of you used to ping once per line of an active
      // group in another room. No `mention:` here — `hasMention` is the room's
      // sticky unread flag, so passing it would un-quiet every later line
      // until the room is read.
      final alert = _burst.shouldAlert(r.id, DateTime.now());
      if (banners) unawaited(_banner(repo, r, quiet: !alert));
      if (!alert) continue;

      // One ping per notify tick even if several rooms advanced at once. This
      // is the in-app awareness sound; the background BANNER belongs to Web
      // Push (`web/mh-push-sw.js`, encrypted by backend/convex/webPush.ts),
      // which is the only thing that reaches a frozen or closed tab. So we do
      // NOT call WebNotifier.showMessage here — that would double the banner
      // on an alive-but-backgrounded tab, where both paths are awake.
      if (!pinged) {
        pinged = true;
        final hook = debugOnPing;
        if (hook != null) {
          hook();
        } else {
          AlertSounds.instance.playPing();
        }
      }
    }
  }

  /// Composes [r]'s card and hands it to the platform's notifier.
  ///
  /// The card is added to synchronously, so lines can never be lost or
  /// reordered; the shown text is re-read from the composer after the avatar
  /// wait, so a slow face on an earlier line cannot overwrite a later one.
  Future<void> _banner(ChatRepository repo, ChatRoom r,
      {required bool quiet}) async {
    final sink = _sink;
    if (sink == null) return;
    final secret = r.isEphemeral && AppOnly.gatesCapture;
    final senderId = r.lastMessageSenderId;
    final sender = senderId == null ? null : repo.userById(senderId);
    final card = _composer.add(
      roomId: r.id,
      isDm: r.isDm,
      title: _bannerTitle(repo, r),
      text: _bannerText(r, secret),
      sender: sender?.displayName,
      // A secret room says only what its chat-list row says, every time.
      replace: secret,
      peerAvatar: repo.otherUserFor(r)?.avatarStorageId,
      roomAvatar: r.avatarStorageId,
      senderAvatar: sender?.avatarStorageId,
    );
    final url = await _avatarUrl(repo, card.avatarStorageId);
    // Read or dismissed while the face was loading.
    final now = _composer.current(r.id);
    if (now == null || !identical(_repo, repo)) return;
    await sink.show(
      roomId: r.id,
      title: now.title,
      body: now.body,
      avatarUrl: url,
      quiet: quiet,
    );
  }

  /// The serving URL for an avatar, from the same cache the chat list uses,
  /// so a face the UI would not show is never shown here either. Never waits
  /// long: a banner without a face beats a late one.
  Future<String?> _avatarUrl(ChatRepository repo, String? storageId) async {
    if (storageId == null) return null;
    final known = FileUrlCache.instance.peek(storageId);
    if (known != null) return known;
    try {
      return await FileUrlCache.instance
          .resolve(storageId, () => repo.api.getFileUrl(storageId))
          .timeout(const Duration(milliseconds: 700));
    } catch (_) {
      return null;
    }
  }

  /// A DM is titled by the person, a group by its name — what the room list
  /// shows on the same row.
  String _bannerTitle(ChatRepository repo, ChatRoom r) {
    if (r.isDm) return repo.otherUserFor(r)?.displayName ?? 'MonkeyHub';
    return r.name;
  }

  /// The preview line. A secret room says only what its chat-list row says
  /// here, because the desktop builds do not open it.
  String _bannerText(ChatRoom r, bool secret) =>
      secret ? appLabels().appOnlySecretPreview : r.lastMessage?.trim() ?? '';
}
