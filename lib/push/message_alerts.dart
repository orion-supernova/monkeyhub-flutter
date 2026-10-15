import 'package:flutter/foundation.dart' show VoidCallback, visibleForTesting;

import '../audio/alert_sounds.dart';
import '../platform.dart';
import '../data/chat_repository.dart';
import '../models/chat_room.dart';
import 'push_manager.dart';
import 'viewer_presence.dart';
import 'web_notifier.dart';

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

  ChatRepository? _repo;
  // roomId → newest message time we've already alerted on (ms since epoch).
  final Map<String, int> _lastSeen = {};

  void setOnOpenRoom(void Function(String roomId) cb) =>
      WebNotifier.setOnOpenRoom(cb);

  void bind(ChatRepository repo) {
    if (!_enabled) return;
    if (identical(_repo, repo)) return;
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
    var pinged = false;
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
      if (!shouldAlert) continue;

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
}
