import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../models/family.dart';

/// Holds the signed-in account's family state and hands it to the UI.
///
/// Every "should this be visible?" decision in the app funnels through here —
/// whether Discover exists, whether Sign Out is offered, whether the call
/// button renders — so those checks stay consistent and there's one place to
/// look when a screen misbehaves for a child.
///
/// [attach] opens a live subscription, so a guardian toggling a rule lands on
/// the child's phone over the already-open socket — no restart. [refresh] is
/// kept as a one-shot fallback for a cold start or a dropped subscription.
///
/// Fails safe: until the first emission the context is [FamilyContext.empty],
/// which reads as an unrestricted adult. That's the right default for the
/// overwhelmingly common case, and every gate is *also* enforced server-side,
/// so a stale client can annoy a child but can't let them past anything.
class FamilyService extends ChangeNotifier {
  FamilyService(this._api);
  final ChatApi _api;

  // Singleton access, mirroring `CallService.ensure` / `.instance`. Screens
  // that already hold a reference should keep using it; this exists for the
  // widgets buried deep in the tree (the call button, the attachment menu)
  // where threading a parameter down would mean touching a dozen unrelated
  // construction sites.
  static FamilyService? _instance;

  /// Null before [ensure] has run — callers in the widget tree should treat
  /// that as "no restrictions known yet" rather than crashing.
  static FamilyService? get maybeInstance => _instance;
  static FamilyService ensure(ChatApi api) =>
      _instance ??= FamilyService(api);

  String? _userId;
  FamilyContext _context = FamilyContext.empty;
  bool _loading = false;

  /// Whether [context] is something the server actually said, rather than the
  /// [FamilyContext.empty] placeholder.
  ///
  /// Matters because `empty` reads as an unrestricted *adult* — the right way
  /// to fail for gating, but indistinguishable from a real "you're an adult"
  /// emission. Anything that acts on `accountType` being adult (see
  /// `_syncAccountType` in app.dart, which rewrites the persisted session) has
  /// to wait for this, or every cold start would graduate a genuine child in
  /// the frames before the subscription lands.
  bool _loaded = false;
  bool get hasContext => _loaded;

  /// Live feed of [FamilyContext]. Null between [detach] and the next
  /// [attach], or if opening the subscription failed — [refresh] is still
  /// there as a fallback in that case.
  Subscription? _sub;

  /// The account an [attach] is currently opening a subscription for. Callers
  /// don't await `attach` (see app.dart), so without this a second call
  /// arriving before the first `subscribe` resolves would open a duplicate and
  /// orphan one of them.
  String? _subscribingFor;

  FamilyContext get context => _context;
  bool get isChild => _context.isChild;
  ChildPolicy get policy => _context.policy;
  int get pendingCount => _context.pendingCount;

  /// True when this account may see Discover / public rooms at all. Adults
  /// always can; a child only once a guardian unlocks it.
  bool get canSeePublicRooms => !isChild || policy.publicRoomsEnabled;

  /// True when the call button should render for this account.
  bool get canCall => !isChild || policy.callsEnabled;

  /// True when the attachment menu should offer photo/video/voice.
  bool get canSendMedia => !isChild || policy.mediaEnabled;

  /// True when "ask to add someone" is available.
  bool get canRequestContacts => !isChild || policy.canRequestContacts;

  /// True when the create-room entry point should render.
  bool get canCreateRooms => !isChild || policy.canCreateRooms;

  /// Re-attaching the *same* user is a no-op only while the subscription is
  /// actually live. If it failed to open (or was torn down), fall through and
  /// try again — otherwise the account would silently stay on stale rules
  /// until the next [refresh].
  Future<void> attach(String userId) async {
    if (_userId == userId && (_sub != null || _subscribingFor == userId)) {
      return;
    }
    final switchingAccounts = _userId != userId;
    _sub?.cancel();
    _sub = null;
    if (switchingAccounts) {
      _userId = userId;
      // Don't leak the previous account's rules into the new one's first frame.
      _context = FamilyContext.empty;
      _loaded = false;
    }
    _subscribingFor = userId;
    try {
      final sub = await _api.subscribeFamilyContext(
        userId: userId,
        onContext: (fresh) {
          if (_userId != userId || fresh == null) return;
          _context = fresh;
          _loaded = true;
          notifyListeners();
        },
        // Transient socket trouble — hold the last known context. The
        // foreground `refresh()` in app.dart reconciles.
        onError: (_) {},
      );
      // A sign-out (or a switch to another account) landed while we were
      // opening. Drop it on the floor rather than leaving a live subscription
      // running for someone who is no longer signed in.
      if (_userId != userId) {
        sub.cancel();
        return;
      }
      _sub = sub;
    } catch (_) {
      _sub = null;
      await refresh();
    } finally {
      if (_subscribingFor == userId) _subscribingFor = null;
    }
  }

  void detach() {
    _sub?.cancel();
    _sub = null;
    // Clearing this makes any subscription still being opened cancel itself
    // when it resolves — see the `_userId != userId` check in [attach].
    _subscribingFor = null;
    _userId = null;
    _context = FamilyContext.empty;
    _loaded = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null || _loading) return;
    _loading = true;
    try {
      final fresh = await _api.getFamilyContext(uid);
      if (fresh != null && _userId == uid) {
        _context = fresh;
        _loaded = true;
        notifyListeners();
      }
    } catch (_) {
      // Offline or transient — keep whatever we had. The server enforces
      // every rule regardless of what this cache says.
    } finally {
      _loading = false;
    }
  }
}
