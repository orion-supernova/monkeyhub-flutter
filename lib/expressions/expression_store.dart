import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart' show Subscription;
import '../family/family_service.dart';
import '../models/expression_item.dart';
import '../models/sticker_pack.dart';
import 'klipy.dart';

/// Everything the expression panel reads that is not a KLIPY search: the KLIPY
/// config, the sticker packs, and the user's recents and favourites.
///
/// One per signed-in account, attached in `app.dart` beside `FeedStore` and
/// detached on sign-out. The detach is not tidiness: a Convex subscription
/// carries the session token it was bound with forever, and one that outlives
/// its session undoes the NEXT sign-in (see `GroupCallService.detach`).
class ExpressionStore extends ChangeNotifier {
  ExpressionStore._();
  static final ExpressionStore instance = ExpressionStore._();

  ChatApi? _api;
  String? _userId;
  Subscription? _packsSub;
  Subscription? _stateSub;

  KlipyClient? _klipy;

  /// The API this store is attached to, for widgets that draw a sticker from
  /// its storage id outside any screen that holds one. Null while signed out.
  ChatApi? get api => _api;

  /// Null when this server has no KLIPY key — the GIF tab is then absent
  /// rather than broken. Also null until [attach]'s config call returns.
  KlipyClient? get klipy => _klipy;

  List<StickerPack> _packs = const [];
  List<StickerPack> get packs => _packs;

  /// Whether the packs subscription has answered once. Distinguishes "no packs
  /// on this server" from "not loaded yet" — see `PendingPlaceholder`.
  bool _packsLoaded = false;
  bool get packsLoaded => _packsLoaded;

  List<ExpressionItem> _recents = const [];
  List<ExpressionItem> _favorites = const [];
  bool _stateLoaded = false;

  List<ExpressionItem> get recents => _recents;
  List<ExpressionItem> get favorites => _favorites;
  bool get stateLoaded => _stateLoaded;

  /// The signed-in user's own personal pack, if they have made a sticker.
  StickerPack? get personalPack {
    for (final p in _packs) {
      if (p.personal) return p;
    }
    return null;
  }

  bool isFavorite(ExpressionItem item) =>
      _favorites.any((f) => f.sameAs(item));

  /// The pack [stickerId] belongs to, if it is one the viewer can see.
  StickerPack? packOf(String? stickerId) {
    if (stickerId == null) return null;
    for (final p in _packs) {
      if (p.stickers.any((s) => s.id == stickerId)) return p;
    }
    return null;
  }

  /// Removes one of the viewer's own stickers. The subscription drops it from
  /// the pack; already-sent messages keep showing it (see the backend).
  Future<void> deletePersonalSticker(String stickerId) async {
    _recents = _recents.where((r) => r.stickerId != stickerId).toList();
    _favorites = _favorites.where((r) => r.stickerId != stickerId).toList();
    notifyListeners();
    await _api?.deletePersonalSticker(stickerId);
  }

  /// A child account whose guardian has switched media off gets official
  /// sticker packs only: no KLIPY (outside pictures) and no personal stickers
  /// (other people's photos). Mirrors the server's child guard, which would
  /// refuse the send anyway — this just keeps the panel from offering it.
  bool get canUseOutsideMedia =>
      FamilyService.maybeInstance?.canSendMedia ?? true;

  bool get _isChild => FamilyService.maybeInstance?.isChild ?? false;

  Future<void> attach(ChatApi api, String userId) async {
    if (_userId == userId && _api != null) return;
    await detach();
    _api = api;
    _userId = userId;

    try {
      _packsSub = await api.subscribeStickerPacks(onPacks: (packs) {
        if (_userId != userId) return;
        _packs = packs;
        _packsLoaded = true;
        notifyListeners();
      });
      _stateSub = await api.subscribeExpressionState(onState: (r, f) {
        if (_userId != userId) return;
        _recents = r;
        _favorites = f;
        _stateLoaded = true;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[expressions] subscribe failed: $e');
    }
    unawaited(_loadConfig(api, userId));
  }

  Future<void> _loadConfig(ChatApi api, String userId) async {
    try {
      final cfg = await api.expressionsConfig();
      if (_userId != userId) return;
      final key = cfg.klipyAppKey;
      _klipy?.close();
      _klipy = key == null
          ? null
          : KlipyClient(
              appKey: key,
              customerId: klipyCustomerId(userId),
              // No ads to children, whatever the server switch says.
              adsEnabled: cfg.klipyAds && !_isChild,
              childSafe: _isChild,
            );
      notifyListeners();
    } catch (e) {
      debugPrint('[expressions] config failed: $e');
    }
  }

  // `async` for the call sites' `await`, which keeps it in the ordered
  // sign-out sequence beside `FeedStore.detach`.
  Future<void> detach() async {
    final packs = _packsSub, state = _stateSub;
    _packsSub = null;
    _stateSub = null;
    _userId = null;
    _api = null;
    _klipy?.close();
    _klipy = null;
    _packs = const [];
    _recents = const [];
    _favorites = const [];
    _packsLoaded = false;
    _stateLoaded = false;
    try {
      packs?.cancel();
      state?.cancel();
    } catch (_) {}
    notifyListeners();
  }

  /// Puts [item] at the front of RECENT now, and on the server behind it.
  ///
  /// Optimistic because the RECENT row is visible the instant the panel next
  /// opens — often before the mutation lands — and a sticker that was just
  /// sent must already be there.
  void noteUsed(ExpressionItem item) {
    _recents = [
      item,
      ..._recents.where((r) => !r.sameAs(item)),
    ].take(40).toList();
    notifyListeners();
    unawaited(_api?.recordExpressionUse(item).catchError((Object e) {
      debugPrint('[expressions] recordUse failed: $e');
    }));
  }

  /// Stars or un-stars [item]. Returns the new state.
  Future<bool> toggleFavorite(ExpressionItem item) async {
    final was = isFavorite(item);
    _favorites = was
        ? _favorites.where((f) => !f.sameAs(item)).toList()
        : [item, ..._favorites];
    notifyListeners();
    try {
      return await _api!.toggleExpressionFavorite(item);
    } catch (e) {
      // Put it back: the star must say what the server holds.
      _favorites = was
          ? [item, ..._favorites]
          : _favorites.where((f) => !f.sameAs(item)).toList();
      notifyListeners();
      rethrow;
    }
  }

  void forgetRecent(ExpressionItem item) {
    _recents = _recents.where((r) => !r.sameAs(item)).toList();
    notifyListeners();
    unawaited(_api?.forgetRecentExpression(item).catchError((Object e) {
      debugPrint('[expressions] forgetRecent failed: $e');
    }));
  }

  /// Every official and personal sticker standing for [emoji], for the
  /// suggestions strip. Variation selectors are ignored on both sides so "❤"
  /// typed without one still finds "❤️".
  List<PackSticker> stickersFor(String emoji) {
    final want = _bare(emoji);
    if (want.isEmpty) return const [];
    return [
      for (final p in _packs)
        if (!p.personal || canUseOutsideMedia)
          for (final s in p.stickers)
            if (_bare(s.emoji) == want) s,
    ];
  }

  static String _bare(String s) => s.replaceAll('️', '').trim();

  @visibleForTesting
  void debugSeed({
    List<StickerPack>? packs,
    List<ExpressionItem>? recents,
    List<ExpressionItem>? favorites,
    KlipyClient? klipy,
  }) {
    if (packs != null) {
      _packs = packs;
      _packsLoaded = true;
    }
    if (recents != null) _recents = recents;
    if (favorites != null) _favorites = favorites;
    if (recents != null || favorites != null) _stateLoaded = true;
    if (klipy != null) _klipy = klipy;
    notifyListeners();
  }
}
