import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web presence: flip the user offline the instant the tab is closing.
///
/// Flutter web never reliably fires `AppLifecycleState.detached` on tab close,
/// so without this a closed tab lingers as "online" until the server staleness
/// sweep catches it (~2 min). `pagehide` fires on close / reload / navigation
/// away, at which point we fire the offline mutation. It's best-effort — a
/// WebSocket send during unload may not flush — but the server-side staleness
/// fallback is the guaranteed backstop.
///
/// We use `pagehide` rather than `visibilitychange`, because visibility → hidden
/// also fires on a mere tab switch (handled separately as "away" via the
/// Flutter lifecycle); only pagehide means the page is actually going away.
class WebPresence {
  const WebPresence._();

  static bool _registered = false;

  static void registerOffline(void Function() onUnload) {
    if (_registered) return;
    _registered = true;
    try {
      web.window.addEventListener(
        'pagehide',
        (web.Event _) {
          onUnload();
        }.toJS,
      );
    } catch (_) {
      // Event wiring unavailable — the server staleness sweep still covers it.
    }
  }
}
