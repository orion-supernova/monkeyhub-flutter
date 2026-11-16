import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ui/foundation/caps.dart';

/// Rewarded videos, the only ad format in the app: a player taps "watch",
/// a video plays, and AdMob tells OUR server (server-side verification) that
/// it was watched, which credits a banana (`backend/convex/lifelines.ts`).
/// The app never credits anything itself; [watch] only reports whether the
/// SDK said the reward was earned, so the wallet knows to look.
///
/// iOS and Android only ([available]). Never for child accounts: the caller
/// checks that, and the server refuses to credit one anyway.
///
/// Non-personalised ads, so no App Tracking Transparency prompt: the app reads
/// nothing to track anyone. Google's consent form (EEA/UK) still runs once,
/// before the first ad, as AdMob requires.
///
/// Design: docs/design/rewarded-ads.md.
class RewardedAds {
  RewardedAds._();
  static final RewardedAds instance = RewardedAds._();

  /// Ours, from the AdMob account (app `MonkeyHub iOS` / `MonkeyHub Android`).
  static const _iosUnit = 'ca-app-pub-8148544480843214/2127467203';
  static const _androidUnit = 'ca-app-pub-8148544480843214/7852622518';

  /// Where a rewarded video can play at all.
  static bool get available => !kIsWeb && Caps.nativeMobile;

  String get _unit => Caps.iOS ? _iosUnit : _androidUnit;

  Future<void>? _init;
  RewardedAd? _ready;
  String? _readyFor;
  Future<RewardedAd?>? _loading;

  static const _request = AdRequest(nonPersonalizedAds: true);

  Future<void> _ensureInit() => _init ??= _initOnce();

  Future<void> _initOnce() async {
    await _consent();
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('rewarded: init: $e');
      return;
    }
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.t),
    );
  }

  /// Google's consent form where the law asks for one. Best effort: an error
  /// here must not cost the player their banana, and AdMob itself refuses to
  /// serve where consent is required and missing.
  Future<void> _consent() async {
    final done = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {}
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    } catch (e) {
      debugPrint('rewarded: consent: $e');
      if (!done.isCompleted) done.complete();
    }
    await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  /// Starts loading a video so the next [watch] opens at once. Call when a
  /// screen that may offer one opens.
  void warm(String userId) {
    if (!available) return;
    unawaited(_load(userId));
  }

  Future<RewardedAd?> _load(String userId) {
    if (_ready != null && _readyFor == userId) return Future.value(_ready);
    return _loading ??= () async {
      try {
        await _ensureInit();
        final got = Completer<RewardedAd?>();
        await RewardedAd.load(
          adUnitId: _unit,
          request: _request,
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) => got.complete(ad),
            onAdFailedToLoad: (e) {
              debugPrint('rewarded: load failed: ${e.code} ${e.message}');
              got.complete(null);
            },
          ),
        );
        final ad = await got.future.timeout(
          const Duration(seconds: 25),
          onTimeout: () => null,
        );
        if (ad != null) {
          await ad.setServerSideOptions(
            ServerSideVerificationOptions(userId: userId),
          );
          _ready = ad;
          _readyFor = userId;
        }
        return ad;
      } catch (e) {
        debugPrint('rewarded: $e');
        return null;
      } finally {
        _loading = null;
      }
    }();
  }

  /// Plays one video. [RewardOutcome.earned] when the SDK says it was watched
  /// to the end (the banana itself arrives through the server a moment
  /// later), [RewardOutcome.skipped] when closed early, [RewardOutcome.noFill]
  /// when there was nothing to show.
  Future<RewardOutcome> watch(String userId) async {
    if (!available) return RewardOutcome.noFill;
    final ad = await _load(userId);
    if (ad == null) return RewardOutcome.noFill;
    _ready = null;
    _readyFor = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        debugPrint('rewarded: show failed: ${e.code} ${e.message}');
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    // The next one starts loading now, so a second banana is one tap away.
    warm(userId);
    return earned ? RewardOutcome.earned : RewardOutcome.skipped;
  }
}

enum RewardOutcome { earned, skipped, noFill }
