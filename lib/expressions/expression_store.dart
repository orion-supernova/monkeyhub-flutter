import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart' show ConvexBackend, Subscription;
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

  /// Every pack: the official catalog in its order, plus the viewer's own.
  /// Official packs arrive as metadata only (`expressions:packList`) and gain
  /// their stickers when first opened ([ensureLoaded]).
  List<StickerPack> _catalog = const [];

  /// Official packs as listed, and the viewer's own pack (a live subscription,
  /// it is small). [_catalog] is these two joined.
  List<StickerPack> _official = const [];
  StickerPack? _personal;

  /// Stickers fetched this session, by pack id. The art never changes, so a
  /// pack is read once per session.
  final Map<String, List<PackSticker>> _loadedStickers = {};
  final Set<String> _loading = {};

  void _rebuildCatalog() {
    _catalog = [
      for (final p in _official)
        if (_loadedStickers[p.id] case final s?) p.withStickers(s) else p,
      ?_personal,
    ];
  }

  /// Fetches [pack]'s stickers once, when its tab or row is opened. A no-op for
  /// a pack that is loaded or loading, and for the viewer's own (live already).
  Future<void> ensureLoaded(StickerPack pack) async {
    if (pack.personal || pack.stickersLoaded) return;
    final id = pack.id;
    if (_loadedStickers.containsKey(id) || !_loading.add(id)) return;
    final userId = _userId;
    try {
      final raw = await ConvexBackend.instance
          .query('expressions:packStickers', {'packId': id});
      if (_userId != userId) return;
      _loadedStickers[id] = [
        for (final s in (raw as List? ?? const []))
          PackSticker.fromJson((s as Map).cast<String, dynamic>(),
              personal: false),
      ];
      _rebuildCatalog();
      notifyListeners();
    } catch (e) {
      debugPrint('[expressions] packStickers failed: $e');
    } finally {
      _loading.remove(id);
    }
  }

  /// Loads every official pack's stickers, once per session. Only for the pack
  /// store's search, which matches packs by the emoji their stickers stand for
  /// and so needs them all; nothing else pays for the whole catalog.
  Future<void> ensureAllLoaded() async {
    await Future.wait([
      for (final p in _official)
        if (!p.stickersLoaded) ensureLoaded(p),
    ]);
  }

  /// Sticker id → pack id, from [resolvePackOf]. Session cache.
  final Map<String, String?> _packIdBySticker = {};

  /// Finds the pack of [stickerId] on the server (one point read) and loads
  /// that pack, so [packOf] answers for a sticker from a pack not opened yet.
  /// Deduped per sticker; a pack that isn't visible to the viewer stays null.
  Future<void> resolvePackOf(String stickerId) async {
    if (_packIdBySticker.containsKey(stickerId)) return;
    _packIdBySticker[stickerId] = null;
    final userId = _userId;
    try {
      final packId = await ConvexBackend.instance
          .query('expressions:packIdOfSticker', {'stickerId': stickerId});
      if (_userId != userId || packId is! String) return;
      _packIdBySticker[stickerId] = packId;
      for (final p in _official) {
        if (p.id == packId) {
          await ensureLoaded(p);
          return;
        }
      }
    } catch (e) {
      debugPrint('[expressions] packIdOfSticker failed: $e');
    }
  }

  /// The official packs the viewer has added, in their order. Null until the
  /// state subscription answers — the strip waits for it rather than flashing
  /// the whole catalog and then shrinking.
  List<String>? _installedIds;

  /// The whole catalog, for the pack store.
  List<StickerPack> get catalog => _catalog;

  /// The strip: the viewer's own pack first, then the packs they have added,
  /// in their order.
  List<StickerPack> get packs {
    final ids = _installedIds;
    if (ids == null) return const [];
    final byId = {for (final p in _catalog) p.id: p};
    return [
      ?personalPack,
      for (final id in ids)
        if (byId[id] case final p? when !p.personal) p,
    ];
  }

  bool isInstalled(String packId) => _installedIds?.contains(packId) ?? false;

  /// Whether both the catalog and the viewer's choices have answered once.
  /// Distinguishes "no packs" from "not loaded yet" — see `PendingPlaceholder`.
  bool _catalogLoaded = false;
  bool get packsLoaded => _catalogLoaded && _installedIds != null;

  List<ExpressionItem> _recents = const [];
  List<ExpressionItem> _favorites = const [];
  bool _stateLoaded = false;

  List<ExpressionItem> get recents => _recents;
  List<ExpressionItem> get favorites => _favorites;
  bool get stateLoaded => _stateLoaded;

  /// The signed-in user's own personal pack, if they have made a sticker.
  StickerPack? get personalPack {
    for (final p in _catalog) {
      if (p.personal) return p;
    }
    return null;
  }

  bool isFavorite(ExpressionItem item) =>
      _favorites.any((f) => f.sameAs(item));

  /// The pack [stickerId] belongs to, added or not — the sticker sheet offers
  /// to add the pack of a sticker somebody else sent.
  StickerPack? packOf(String? stickerId) {
    if (stickerId == null) return null;
    for (final p in _catalog) {
      if (p.stickers.any((s) => s.id == stickerId)) return p;
    }
    return null;
  }

  /// Adds an official pack to the strip (at the end) or takes it off.
  ///
  /// Optimistic, like [noteUsed]: the store's buttons flip on the tap, and the
  /// subscription confirms a moment later. A refusal puts the list back.
  Future<void> setInstalled(StickerPack pack, bool installed) async {
    if (pack.personal) return;
    final before = _installedIds ?? const <String>[];
    final without = before.where((id) => id != pack.id).toList();
    _installedIds = installed ? [...without, pack.id] : without;
    notifyListeners();
    try {
      await _api?.setStickerPackInstalled(pack.id, installed);
    } catch (e) {
      _installedIds = before;
      notifyListeners();
      rethrow;
    }
  }

  /// Puts the added packs in [ids]' order — the store's drag handle.
  void reorderInstalled(List<String> ids) {
    final before = _installedIds;
    _installedIds = ids;
    notifyListeners();
    unawaited(_api?.reorderStickerPacks(ids).catchError((Object e) {
      debugPrint('[expressions] reorder failed: $e');
      _installedIds = before;
      notifyListeners();
    }));
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
      // Pack metadata is static: one query a session, not a subscription.
      unawaited(_loadPackList(userId));
      // The viewer's own pack stays live (a sticker made on another device).
      _packsSub = await ConvexBackend.instance.subscribe(
        'expressions:personalPack',
        const {},
        onData: (raw) {
          if (_userId != userId) return;
          _personal = raw == null
              ? null
              : StickerPack.fromJson((raw as Map).cast<String, dynamic>());
          _rebuildCatalog();
          notifyListeners();
        },
        onError: (e) => debugPrint('[expressions] personal pack: $e'),
      );
      _stateSub = await api.subscribeExpressionState(onState: (r, f, ids) {
        if (_userId != userId) return;
        _recents = r;
        _favorites = f;
        _installedIds = ids;
        _stateLoaded = true;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[expressions] subscribe failed: $e');
    }
    unawaited(_loadConfig(api, userId));
  }

  Future<void> _loadPackList(String userId) async {
    try {
      final raw = await ConvexBackend.instance.query('expressions:packList', {});
      if (_userId != userId) return;
      _official = [
        for (final p in (raw as List? ?? const []))
          StickerPack.fromJson((p as Map).cast<String, dynamic>()),
      ];
      _catalogLoaded = true;
      _rebuildCatalog();
      notifyListeners();
    } catch (e) {
      debugPrint('[expressions] packList failed: $e');
    }
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
    _catalog = const [];
    _official = const [];
    _personal = null;
    _loadedStickers.clear();
    _loading.clear();
    _installedIds = null;
    _recents = const [];
    _favorites = const [];
    _catalogLoaded = false;
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

  /// Every sticker in the viewer's strip — their own pack and the packs they
  /// have added — standing for [emoji], for the suggestions strip. Packs they
  /// have not added stay out: suggesting from the whole catalog would undo
  /// their choice. Variation selectors are ignored on both sides so "❤" typed
  /// without one still finds "❤️".
  List<PackSticker> stickersFor(String emoji) {
    final want = _bare(emoji);
    if (want.isEmpty) return const [];
    // Packs are fetched when opened; suggestions need the strip's packs, so
    // start loading any that are not in yet (they show on the next call).
    for (final p in packs) {
      if (!p.stickersLoaded) unawaited(ensureLoaded(p));
    }
    return [
      for (final p in packs)
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
    // Seeded packs are all "added", so a test sees them in the strip without
    // also seeding the viewer's choices.
    if (packs != null) {
      _catalog = packs;
      _catalogLoaded = true;
      _installedIds = [for (final p in packs) if (!p.personal) p.id];
    }
    if (recents != null) _recents = recents;
    if (favorites != null) _favorites = favorites;
    if (recents != null || favorites != null) _stateLoaded = true;
    if (klipy != null) _klipy = klipy;
    notifyListeners();
  }
}
