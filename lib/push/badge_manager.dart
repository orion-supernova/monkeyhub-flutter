import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../family/family_service.dart';
import 'web_badge.dart';

/// Computes a single "needs attention" number for this user and pushes it to
/// the platform app icon. The number aggregates:
///   - count of incoming friend / direct requests
///   - pending group invites this user may actually answer
///   - anything waiting on this user AS A GUARDIAN — their children's
///     approvals queue
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

  /// The guardian half of the number.
  ///
  /// Separate from [_repo] because it lives on a different subscription — the
  /// family context — and because most accounts never have one. Null simply
  /// contributes zero, so a caller that does not bind it is not wrong, only
  /// incomplete.
  FamilyService? _family;

  int _total = 0;
  int get total => _total;

  /// Whether the number on the app icon might have been written by somebody
  /// other than us — which is to say, whether we are still entitled to skip a
  /// platform write because [_total] has not moved.
  ///
  /// True in a fresh process and again after every trip through the
  /// background, because every push carries an absolute `ios_badgeCount` and
  /// APNs applies it whether this process is running or not. So the OS can be
  /// showing 1 while [_total] still reads the 0 it held when the app went
  /// away, and "unchanged" then means "unchanged from a value the icon never
  /// had". That is the badge that survives reading the room it belongs to: on
  /// a notification tap the room is opened at once, and `markRoomRead` can
  /// land before the room-list subscription has refired even once — so the
  /// first fire after coming back already says 0, matches [_total], and the
  /// write that would have cleared the icon is skipped.
  bool _platformUnknown = true;

  /// The room-list snapshot [_recompute] last saw. [ChatRepository.facetCounts]
  /// is memoised per room-list write, so its identity changing is exactly the
  /// signal "the server has told us about rooms again" — which is when a
  /// re-assert is worth making and, equally, when it is safe to make. Asserting
  /// on the resume edge instead would write the stale pre-background total over
  /// a push's newer one.
  Object? _lastCounts;

  void bind(ChatRepository repo, {FamilyService? family}) {
    final sameRepo = identical(_repo, repo);
    final sameFamily = identical(_family, family);
    if (sameRepo && sameFamily) return;
    if (!sameRepo) {
      _repo?.removeListener(_recompute);
      _repo = repo;
      repo.addListener(_recompute);
    }
    if (!sameFamily) {
      _family?.removeListener(_recompute);
      _family = family;
      family?.addListener(_recompute);
    }
    _platformUnknown = true;
    _lastCounts = null;
    _recompute();
  }

  void unbind() {
    _repo?.removeListener(_recompute);
    _repo = null;
    _family?.removeListener(_recompute);
    _family = null;
    _total = 0;
    _platformUnknown = true;
    _lastCounts = null;
    notifyListeners();
    _writePlatform(0);
  }

  /// The app went away, so a push may write the icon behind our back. Called
  /// from the lifecycle handler in app.dart on every non-resumed state.
  void invalidatePlatformBadge() => _platformUnknown = true;

  void _recompute() {
    final repo = _repo;
    if (repo == null) return;
    // Identity, not value: this is asking whether the list was re-delivered,
    // not whether the counts in it came out the same.
    final counts = repo.facetCounts;
    final listMoved = !identical(counts, _lastCounts);
    _lastCounts = counts;
    // The same four terms `badges.badgeTotalFor` sums server-side, in the same
    // order. They are two independent computations of one number and they are
    // visibly wrong the moment they disagree: every push stamps an absolute
    // count onto the icon, and this is what re-asserts it on resume — so a
    // term missing here does not merely under-count, it ERASES whatever the
    // push had correctly put there.
    final next = repo.incomingRequests.length +
        repo.roomInvitations.length +
        (_family?.pendingCount ?? 0) +
        repo.unreadMessageTotal;
    final numberMoved = next != _total;
    // Two reasons to write, and the second is the whole point of the flag: the
    // number moved, or it did not but the icon is not known to be showing it
    // and the room list has just answered afresh, so what we hold is worth
    // asserting. Everything else — a typing notify, a reaction, a room-list
    // fire that changed nothing on an icon we already trust — writes nothing.
    if (!numberMoved && !(listMoved && _platformUnknown)) return;

    _total = next;
    _platformUnknown = false;
    if (numberMoved) notifyListeners();
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
    // Android: intentional no-op, and not for the reason this line used to
    // give (it named the push vendor, which has not existed since
    // `feat(push): the notifications stop going through a vendor`). Android
    // has no OS-level badge API at all — launchers derive the dot or count
    // from the app's ACTIVE notifications, which `ChatNotifications` already
    // posts and dismisses per room. Writing a number here would have nowhere
    // to write it to.
  }
}
