import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import 'push_manager.dart';
import 'web_badge.dart';

/// Computes a single "needs attention" number for this user and pushes it to
/// the platform app icon. The number aggregates:
///   - count of incoming friend / direct requests
///   - count of rooms with a message newer than the last time the user
///     opened them (best-effort; we don't yet persist a per-room read marker
///     so this currently degrades to 0)
///
/// The platform write is dispatched per platform by [_writePlatform]:
///   - iOS / macOS / Windows / Linux → the native `monkeyhub/badge` method
///     channel; each runner sets its app-icon / dock / taskbar / launcher badge.
///   - Web → [WebBadge]: tab title + favicon bubble (+ `navigator.setAppBadge`
///     when the app is an installed PWA). A browser tab has no app-icon badge.
///   - Android → no-op: badges are notification-channel-driven and handled by
///     OneSignal directly; we don't override that here.
/// Backend pushes already set the iOS badge via the OneSignal payload — this
/// manager is responsible for the in-process truth and for *clearing* the
/// badge when the user reopens the app.
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
    final next = repo.incomingRequests.length;
    if (next == _total) return;
    _total = next;
    notifyListeners();
    _writePlatform(_total);
  }

  /// Reset the platform badge — fire when the app resumes to the foreground
  /// since OneSignal won't auto-clear it on iOS.
  Future<void> clear() async {
    _total = 0;
    notifyListeners();
    await _writePlatform(0);
    await PushManager.instance.setBadge(0);
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
