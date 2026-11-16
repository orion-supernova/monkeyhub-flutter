import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/convex_client.dart';
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

  /// Whether this device can play a video for this account.
  bool get canWatch => RewardedAds.available && !childAccount;

  int balance = 0;
  int adsToday = 0;
  int adsLeft = 15;

  /// Ads until the one that pays double (1 = the next one does).
  int nextBonusIn = 3;
  bool freeReady = false;
  bool loaded = false;

  void _apply(dynamic res) {
    if (res is! Map) return;
    balance = (res['balance'] as num?)?.toInt() ?? balance;
    adsToday = (res['adsToday'] as num?)?.toInt() ?? adsToday;
    adsLeft = (res['adsLeft'] as num?)?.toInt() ?? adsLeft;
    nextBonusIn = (res['nextBonusIn'] as num?)?.toInt() ?? nextBonusIn;
    freeReady = res['freeReady'] as bool? ?? freeReady;
    loaded = true;
    notifyListeners();
  }

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
