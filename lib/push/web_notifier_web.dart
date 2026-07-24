import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web message notifications via the browser Notification API.
///
/// Shows an OS-level banner for a new message when the tab is hidden (a visible
/// tab already gets the in-app ping, so a banner then would double-alert). The
/// banner click focuses the tab and opens the room. Permission must be
/// requested from a user gesture — see the prime-on-first-interaction wiring in
/// `app.dart`.
///
/// Fully-closed-tab delivery would require Web Push + a service worker; that is
/// out of scope here — this covers the foreground and backgrounded-tab cases.
class WebNotifier {
  const WebNotifier._();

  static void Function(String roomId)? _onOpenRoom;
  static void setOnOpenRoom(void Function(String roomId) cb) =>
      _onOpenRoom = cb;

  // Monotonic so every banner gets a UNIQUE tag. A stable per-room tag caused
  // the browser to silently replace the existing banner on each new message
  // (no pop, no sound) even with renotify — so only the first message alerted.
  static int _seq = 0;

  // The currently-showing incoming-call banner, so we can close it when the
  // call stops ringing.
  static web.Notification? _call;

  /// Ask the browser for notification permission, once, if still undecided.
  /// Must be called from within a user gesture or some browsers ignore it.
  static Future<void> requestPermission() async {
    try {
      if (web.Notification.permission == 'default') {
        await web.Notification.requestPermission().toDart;
      }
    } catch (_) {
      // Notification API unavailable (older browser / insecure origin) — ignore.
    }
  }

  /// True only when the document is actually focused — i.e. the tab is the
  /// active tab AND its window has focus. `document.hidden` is false for a
  /// visible tab in an *unfocused* window, so `hasFocus()` is the correct
  /// "is the user looking at us" signal. Used by [MessageAlerts] to decide
  /// whether a new message needs an alert.
  static bool get isFocused {
    try {
      return web.document.hasFocus();
    } catch (_) {
      return true; // assume focused if the API is unavailable
    }
  }

  static void showMessage({
    required String title,
    required String body,
    required String roomId,
  }) {
    try {
      if (web.Notification.permission != 'granted') return;
      // The caller (MessageAlerts) already decided a banner is warranted
      // (app not focused), so we don't re-gate on visibility here.
      final n = web.Notification(
        title,
        web.NotificationOptions(
          body: body,
          // Unique tag → each message is its own banner that pops + sounds,
          // instead of silently replacing the previous one.
          tag: 'msg:$roomId:${_seq++}',
          icon: 'favicon.png',
        ),
      );
      n.addEventListener(
        'click',
        (web.Event _) {
          try {
            web.window.focus();
          } catch (_) {}
          _onOpenRoom?.call(roomId);
          n.close();
        }.toJS,
      );
    } catch (_) {
      // Notification construction can throw in unsupported contexts — ignore.
    }
  }

  /// Persistent incoming-call banner. Unlike a message, a call is time-critical,
  /// so it stays up (`requireInteraction`) until answered/declined and is closed
  /// via [dismissCall]. Kept non-silent so the OS plays its sound — a reliable
  /// background alert even when audio autoplay is blocked. Click focuses the
  /// window, where the in-app incoming-call screen is waiting.
  static void showCall({required String title, required String body}) {
    try {
      if (web.Notification.permission != 'granted') return;
      dismissCall(); // never stack two call banners
      final n = web.Notification(
        title,
        web.NotificationOptions(
          body: body,
          tag: 'call:${_seq++}',
          icon: 'favicon.png',
          requireInteraction: true,
        ),
      );
      n.addEventListener(
        'click',
        (web.Event _) {
          try {
            web.window.focus();
          } catch (_) {}
          n.close();
        }.toJS,
      );
      _call = n;
    } catch (_) {
      // Notification construction can throw in unsupported contexts — ignore.
    }
  }

  /// Close the incoming-call banner (call answered, declined, cancelled, timed
  /// out). Safe to call when none is showing.
  static void dismissCall() {
    try {
      _call?.close();
    } catch (_) {}
    _call = null;
  }
}
