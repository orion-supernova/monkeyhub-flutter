import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../models/family.dart';

/// Holds the signed-in account's family state and hands it to the UI.
///
/// Every "should this be visible?" decision in the app funnels through here —
/// whether Discover exists, whether Sign Out is offered, whether the call
/// button renders — so those checks stay consistent and there's one place to
/// look when a screen misbehaves for a child.
///
/// Fails safe: until [refresh] has succeeded the context is [FamilyContext
/// .empty], which reads as an unrestricted adult. That's the right default
/// for the overwhelmingly common case, and every gate is *also* enforced
/// server-side, so a stale client can annoy a child but can't let them past
/// anything.
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

  Future<void> attach(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    _context = FamilyContext.empty;
    await refresh();
  }

  void detach() {
    _userId = null;
    _context = FamilyContext.empty;
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
