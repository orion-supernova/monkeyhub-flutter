import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../audio/alert_sounds.dart';
import '../platform.dart';
import '../data/chat_repository.dart';
import '../models/chat_room.dart';
import 'web_notifier.dart';

/// Plays a sound (and, on web, shows a browser banner) when a new inbound
/// message arrives in a room the user isn't currently viewing.
///
/// Why this exists: on mobile, APNs/FCM deliver a banner with the OS
/// notification sound. Desktop has no push at all, and a FOREGROUND web tab
/// gets no Web Push banner either, so new messages arrived silently. This
/// observes the rooms-list subscription — which refires with an advanced
/// `lastMessageTime` on every new message — and fires an alert when a room's
/// newest message moves forward while the room `hasUnread` (i.e. it isn't the
/// user's own send) and isn't the room on screen.
///
/// Scope: web + desktop only. Mobile is served by the OS notification.
class MessageAlerts {
  MessageAlerts._();
  static final MessageAlerts instance = MessageAlerts._();

  /// Web (autoplay + Notification API) and desktop (no native push) need this;
  /// mobile is served by OneSignal.
  static bool get _enabled => isWebOrDesktop;

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
  bool get _focused {
    if (kIsWeb) return WebNotifier.isFocused;
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  void _onChange() {
    final repo = _repo;
    if (repo == null) return;
    final active = repo.activeRoomId;
    final focused = _focused;
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
      final isActive = r.id == active;
      final shouldAlert = isActive ? !focused : r.hasUnread;
      if (!shouldAlert) continue;

      // One ping per notify tick even if several rooms advanced at once. This
      // is the in-app awareness sound; the background BANNER is owned by
      // OneSignal Web Push now (see web/index.html + onesignal_web.dart), which
      // is the only thing that reaches a frozen/closed tab — and it suppresses
      // itself while the page is focused. So we no longer call
      // WebNotifier.showMessage here (that would double the banner on an
      // alive-but-backgrounded tab).
      if (!pinged) {
        pinged = true;
        AlertSounds.instance.playPing();
      }
    }
  }
}
