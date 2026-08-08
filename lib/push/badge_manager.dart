import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import 'web_badge.dart';

/// Computes a single "needs attention" number for this user and pushes it to
/// the platform app icon. The number aggregates:
///   - count of incoming friend / direct requests
///   - total unread messages across every room, from the server-computed
///     per-room `unreadCount` (see backend `badges.ts`)
///
/// This must stay in step with the absolute `ios_badgeCount` the backend
/// stamps into every push — the two are independent computations of the same
/// number, and they'd be visibly wrong if they diverged.
///
/// The platform write is dispatched per platform by [_writePlatform]:
///   - iOS / macOS / Windows / Linux → the native `monkeyhub/badge` method
///     channel; each runner sets its app-icon / dock / taskbar / launcher badge.
///   - Web → [WebBadge]: tab title + favicon bubble (+ `navigator.setAppBadge`
///     when the app is an installed PWA). A browser tab has no app-icon badge.
///   - Android → no-op: launchers derive a badge from the posted notifications
///     and their channel, so there is nothing for us to set.
/// Backend pushes already carry an absolute iOS badge value in `aps.badge` —
/// this manager is responsible for the in-process truth and for re-asserting it
/// when the user reopens the app.
class BadgeManager extends ChangeNotifier {
  BadgeManager._();
  static final BadgeManager instance = BadgeManager._();

  static const _ch = MethodChannel('monkeyhub/badge');

  ChatRepository? _repo;
  int _total = 0;
  int get total => _total;

  void bind(ChatRepository repo) {
    if (identical(_repo, repo)) return;
    _repo?.removeListener(_recompute);
    _repo = repo;
    repo.addListener(_recompute);
    _recompute();
  }

  void unbind() {
    _repo?.removeListener(_recompute);
    _repo = null;
    _total = 0;
    notifyListeners();
    _writePlatform(0);
  }

  void _recompute() {
    final repo = _repo;
    if (repo == null) return;
    final next = repo.incomingRequests.length + repo.unreadMessageTotal;
    if (next == _total) return;
    _total = next;
    notifyListeners();
    _writePlatform(_total);
  }

  /// Re-assert the true badge value — fire when the app resumes to the
  /// foreground, since iOS won't recompute it on its own.
  ///
  /// This deliberately does NOT zero the badge. Under the old `Increase`
  /// payload the badge carried no meaning of its own, so clearing on resume
  /// was the only correction available. Now that every push carries an
  /// absolute `SetTo` count, zeroing here would wipe a legitimately unread
  /// total the moment the user glanced at an unrelated screen.
  Future<void> sync() async {
    _recompute();
    await _writePlatform(_total);
  }

  Future<void> _writePlatform(int n) async {
    // Web: no app-icon badge on a browser tab — reflect the count in the tab
    // title + favicon (and setAppBadge for installed PWAs).
    if (kIsWeb) {
      WebBadge.set(n);
      return;
    }
    // Native desktop/mobile app-icon badge via the shared `monkeyhub/badge`
    // channel. Each runner (iOS/macOS/Windows/Linux) implements `set`; an
    // unregistered handler throws MissingPluginException, swallowed below.
    if (Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux) {
      try {
        await _ch.invokeMethod('set', {'count': n});
      } catch (e) {
        // Native side may not be wired yet; safe to swallow.
        debugPrint('BadgeManager native write failed: $e');
      }
      return;
    }
    // Android: notification-driven via OneSignal — intentional no-op.
  }
}
