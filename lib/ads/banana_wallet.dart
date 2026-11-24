import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/convex_client.dart';
import '../fight/view/art/art_common.dart' show FightLook;
import '../games/catalog.dart';
import 'rewarded_ads.dart';

/// What a banana buys. Mirrors `spend`'s `kind` in backend/convex/lifelines.ts.
enum BananaUse {
  /// One more guess in today's Code puzzle (up to 3).
  guess,

  /// One more hint in a daily, past the free ones (up to 3).
  hint,

  /// One more takeback against a bot.
  undo,

  /// Get back up against the bot in Jungle Fist.
  fightContinue,

  /// Keep a streak that missed one day. Costs [BananaWallet.streakCost].
  streak;

  String get wire => switch (this) {
    BananaUse.fightContinue => 'continue',
    _ => name,
  };

  int get cost => this == BananaUse.streak ? BananaWallet.streakCost : 1;
}

/// The signed-in player's bananas: the rewarded-ad currency.
///
/// Not a subscription: the wallet changes only when this player spends, claims
/// or watches, so it is read when a sheet opens and after each of those. A
/// watched video's banana arrives through AdMob's callback to the server a
/// moment after the video closes; [watchAd] polls briefly for it.
class BananaWallet extends ChangeNotifier {
  BananaWallet._();
  static final BananaWallet instance = BananaWallet._();

  static const streakCost = 2;

  ConvexBackend get _cv => ConvexBackend.instance;

  /// Set by the app shell on every auth change: no videos for a child.
  bool childAccount = false;

  /// The signed-in user, set by the app shell on every auth change; the
  /// sheets that have no user id of their own read it.
  String? userId;

  /// Whether this device can play a video for this account.
  bool get canWatch => RewardedAds.available && !childAccount;

  int balance = 0;
  int adsToday = 0;
  int adsLeft = 15;

  /// Ads until the one that pays double (1 = the next one does).
  int nextBonusIn = 3;
  bool freeReady = false;
  bool loaded = false;

  /// Catalog ids this account owns (`fighter.golem`, ...). A bundle grants
  /// its members; [ownsItem] answers for a bundle.
  Set<String> owned = {};

  /// The one free first unlock (a fighter or stage up to 90) is still unused.
  bool firstPickReady = false;

  /// The first pack bought credits double.
  bool firstPackBonus = false;

  /// The server's list prices (singles and bundles); wins over the catalog.
  Map<String, int> prices = {};

  /// Set for a supervised account: whether it may ask, and what its own
  /// bananas may buy (`all` | `lifelines` | `none`). Null for adults.
  ({bool ask, String spend})? child;

  /// A child with an `all` policy spends their own bananas on unlocks.
  bool get childMaySpendOnUnlocks => child != null && child!.spend == 'all';

  bool owns(String itemId) => owned.contains(itemId);

  bool ownsFighter(int id) => isFreeFighter(id) || owns(fighterItemId(id));
  bool ownsStage(int id) => isFreeStage(id) || owns(stageItemId(id));
  bool ownsLook(FightLook look) => isFreeLook(look) || owns(lookItemId(look));

  /// Whether this account may start [game] (free, or unlocked).
  bool canSendGame(String game) => isFreeGame(game) || owns(gameItemId(game));

  /// What [itemId] costs this account now. Singles: the server's list, else
  /// the catalog. Bundles: complete-the-set, the list price scaled by what is
  /// still unowned (ceil); 0 once every member is owned.
  int priceOf(String itemId) {
    final item = catalogItem(itemId);
    final list = prices[itemId] ?? item?.price ?? 0;
    if (item == null || !item.isBundle) return list;
    var all = 0;
    var unowned = 0;
    for (final m in item.members) {
      final p = prices[m] ?? catalogItem(m)?.price ?? 0;
      all += p;
      if (!owns(m)) unowned += p;
    }
    if (unowned == 0 || owns(itemId)) return 0;
    if (all == 0) return list;
    return (list * unowned / all).ceil();
  }

  /// A bundle is owned when nothing is left to buy; a single when held.
  bool ownsItem(String itemId) {
    final item = catalogItem(itemId);
    if (item == null) return owns(itemId);
    if (item.isBundle) return owns(itemId) || item.members.every(owns);
    return owns(itemId);
  }

  /// Applies the unlock fields of a `lifelines:mine` or `unlocks:buy` reply.
  void applyUnlocks(dynamic res) {
    if (res is! Map) return;
    final o = res['owned'];
    if (o is List) owned = {for (final e in o) e.toString()};
    firstPickReady = res['firstPickReady'] as bool? ?? firstPickReady;
    firstPackBonus = res['firstPackBonus'] as bool? ?? firstPackBonus;
    final p = res['prices'];
    if (p is Map) {
      prices = {
        for (final e in p.entries)
          if (e.value is num) e.key.toString(): (e.value as num).toInt(),
      };
    }
    if (res.containsKey('child')) {
      final c = res['child'];
      child = c is Map
          ? (ask: c['ask'] as bool? ?? true, spend: c['spend'] as String? ?? 'lifelines')
          : null;
    }
  }

  /// Buys [itemId] (a single or a bundle; the server prices it). Set
  /// [firstPick] to spend the free first unlock. Throws the server's code
  /// (`NO_BANANAS`, `OWNED`, `CHILD_ASK`, ...) in the error's text.
  Future<void> unlock(
    String userId,
    String itemId, {
    bool firstPick = false,
  }) async {
    final res = await _cv.mutation('unlocks:buy', {
      'userId': userId,
      'item': itemId,
      if (firstPick) 'firstPick': true,
    });
    if (res is Map) {
      if (res['balance'] is num) balance = (res['balance'] as num).toInt();
      applyUnlocks(res);
      if (firstPick) firstPickReady = false;
    }
    notifyListeners();
  }

  /// The launch gift, asked once per Games tab open. Returns the bananas
  /// granted (0 almost always).
  Future<int> welcome(String userId) async {
    if (debugOffline) return 0;
    try {
      final res = await _cv.mutation('lifelines:welcome', {'userId': userId});
      final gift = res is Map ? (res['gift'] as num?)?.toInt() ?? 0 : 0;
      if (gift > 0) await refresh(userId);
      return gift;
    } catch (e) {
      debugPrint('bananas welcome: $e');
      return 0;
    }
  }

  void _apply(dynamic res) {
    if (res is! Map) return;
    balance = (res['balance'] as num?)?.toInt() ?? balance;
    adsToday = (res['adsToday'] as num?)?.toInt() ?? adsToday;
    adsLeft = (res['adsLeft'] as num?)?.toInt() ?? adsLeft;
    nextBonusIn = (res['nextBonusIn'] as num?)?.toInt() ?? nextBonusIn;
    freeReady = res['freeReady'] as bool? ?? freeReady;
    applyUnlocks(res);
    loaded = true;
    notifyListeners();
  }

  /// Parses a `lifelines:mine` reply, for tests.
  @visibleForTesting
  void debugApply(dynamic res) => _apply(res);

  /// Tests and previews: never touch the backend.
  @visibleForTesting
  static bool debugOffline = false;

  Future<void> refresh(String userId) async {
    if (debugOffline) return;
    try {
      _apply(await _cv.query('lifelines:mine', {'userId': userId}));
    } catch (e) {
      debugPrint('bananas: $e');
    }
  }

  /// Today's free banana. True when one was added.
  Future<bool> claimFree(String userId) async {
    final res = await _cv.mutation('lifelines:claimFree', {'userId': userId});
    await refresh(userId);
    return res is Map && res['claimed'] == true;
  }

  /// Spends on [use]. Throws the server's refusal code (`NO_BANANAS`,
  /// `LIMIT`, `NOT_NEEDED`, ...) in the error's text.
  Future<void> spend(
    String userId,
    BananaUse use, {
    String? dayKey,
    String? game,
  }) async {
    final res = await _cv.mutation('lifelines:spend', {
      'userId': userId,
      'kind': use.wire,
      'dayKey': ?dayKey,
      'game': ?game,
    });
    if (res is Map && res['balance'] is num) {
      balance = (res['balance'] as num).toInt();
      notifyListeners();
    }
  }

  /// How the last [watchAd] went, for the sheet to say so.
  WatchOutcome lastOutcome = WatchOutcome.skipped;

  /// Starts loading a video so the next [watchAd] opens at once.
  void watchWarm(String userId) {
    if (canWatch && !debugOffline) RewardedAds.instance.warm(userId);
  }

  /// Plays a video and waits for its banana(s). Returns how many arrived:
  /// 0 when the video was skipped, had no fill, or the server never heard
  /// back within the wait (it may still land later; the next refresh shows).
  Future<int> watchAd(String userId) async {
    if (!canWatch) return 0;
    final before = balance;
    final outcome = await RewardedAds.instance.watch(userId);
    if (outcome != RewardOutcome.earned) {
      lastOutcome = outcome == RewardOutcome.noFill
          ? WatchOutcome.noVideo
          : WatchOutcome.skipped;
      return 0;
    }
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration(milliseconds: i < 5 ? 500 : 1000));
      await refresh(userId);
      if (balance > before) {
        lastOutcome = WatchOutcome.credited;
        return balance - before;
      }
    }
    lastOutcome = WatchOutcome.late;
    return 0;
  }
}

enum WatchOutcome { credited, skipped, noVideo, late }
