import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../env.dart';
import '../games/catalog.dart' show kPackBananas;
import '../ui/foundation/caps.dart';
import 'banana_wallet.dart';

/// One banana pack on sale: RevenueCat's package, with its store price.
class BananaPack {
  const BananaPack({
    required this.id,
    required this.bananas,
    required this.priceString,
    this.package,
  });

  /// `handful`, `basket`, `crate`, `tree` or `jungle`.
  final String id;

  /// Bananas credited by the server for this pack (before any first-pack
  /// doubling).
  final int bananas;

  /// Localised, from the store ("$4.99").
  final String priceString;

  /// The RevenueCat package; null in tests.
  final Package? package;
}

/// Banana packs bought with real money, through RevenueCat.
///
/// The app never credits anything itself: a purchase ends in RevenueCat's
/// webhook to the server (`/revenuecat`), which credits the wallet; [buy]
/// only polls [BananaWallet.refresh] until it lands. The RevenueCat app user
/// id is the Convex user id, which is how the webhook knows who bought.
///
/// iOS, macOS and Android, never for a child account. Needs the public SDK
/// key for the platform in env.local (`REVENUECAT_APPLE_KEY` /
/// `REVENUECAT_GOOGLE_KEY`); without it [available] is false and the shop
/// shows no packs.
class BananaStore {
  BananaStore._();
  static final BananaStore instance = BananaStore._();

  static const offeringId = 'bananas';

  /// Tests and previews: pretend the store is (not) there.
  @visibleForTesting
  static bool? debugAvailable;

  /// Whether the last [buy] ended because the player backed out.
  bool lastCancelled = false;

  String? _configured;
  Future<void>? _configuring;

  static String get _key =>
      Caps.android ? Env.revenueCatGoogleKey : Env.revenueCatAppleKey;

  static bool get _platformOk => !kIsWeb && (Caps.nativeApple || Caps.android);

  /// Whether this device can sell packs to this account.
  bool get available =>
      debugAvailable ??
      (_platformOk && _key.isNotEmpty && !BananaWallet.instance.childAccount);

  /// Call on every auth change with the signed-in user id, or null on sign
  /// out. Configures the SDK once, logs in on an account switch, logs out
  /// when signed out. Never throws.
  Future<void> configure(String? userId) {
    if (!_platformOk || _key.isEmpty) return Future.value();
    // Serialised: auth changes can arrive back to back.
    final prev = _configuring ?? Future<void>.value();
    return _configuring = prev.then((_) => _apply(userId)).catchError((Object e) {
      debugPrint('bananaStore: $e');
    });
  }

  Future<void> _apply(String? userId) async {
    if (userId == null) {
      if (_configured == null) return;
      _configured = null;
      if (await Purchases.isConfigured && !await Purchases.isAnonymous) {
        await Purchases.logOut();
      }
      return;
    }
    if (_configured == userId) return;
    if (!await Purchases.isConfigured) {
      await Purchases.configure(
        PurchasesConfiguration(_key)..appUserID = userId,
      );
    } else {
      await Purchases.logIn(userId);
    }
    _configured = userId;
  }

  /// The packs on sale, cheapest first, from the `bananas` offering. Empty
  /// when the store is unavailable or the offering is not set up.
  Future<List<BananaPack>> packs() async {
    if (!available) return const [];
    try {
      await _configuring;
      final offering = (await Purchases.getOfferings()).getOffering(offeringId);
      if (offering == null) return const [];
      final out = <BananaPack>[];
      for (final p in offering.availablePackages) {
        final bananas = kPackBananas[p.identifier];
        if (bananas == null) continue;
        out.add(BananaPack(
          id: p.identifier,
          bananas: bananas,
          priceString: p.storeProduct.priceString,
          package: p,
        ));
      }
      out.sort((a, b) => a.bananas.compareTo(b.bananas));
      return out;
    } catch (e) {
      debugPrint('bananaStore packs: $e');
      return const [];
    }
  }

  /// Buys [pack] and waits for the server's credit. Returns the bananas
  /// added (0 when the player cancelled, or the credit has not arrived
  /// within ~20 s; it may still land, the next refresh shows). Throws on a
  /// store failure.
  Future<int> buy(String userId, BananaPack pack) async {
    final package = pack.package;
    if (package == null) return 0;
    final wallet = BananaWallet.instance;
    final before = wallet.balance;
    lastCancelled = false;
    try {
      await Purchases.purchase(PurchaseParams.package(package));
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        lastCancelled = true;
        return 0;
      }
      rethrow;
    }
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration(milliseconds: i < 5 ? 500 : 1000));
      await wallet.refresh(userId);
      if (wallet.balance > before) return wallet.balance - before;
    }
    return 0;
  }
}
