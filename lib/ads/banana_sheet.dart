import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../family/banana_requests_strip.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/link_opener.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../update/update_destination.dart' show kDownloadPageUrl;
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/sheet_kit.dart' show SheetActionButton, SheetFrame;
import 'banana_glyph.dart';
import 'banana_shop.dart';
import 'banana_wallet.dart';

/// Offers to spend bananas on [use], and to earn them right here when the
/// wallet is short. Resolves true once the bananas were spent on the server,
/// so the caller grants the thing (or retries the call that was refused).
///
/// The loop it is built for: short of a banana, one tap plays a video, the
/// banana lands with a pop, and it is spent at once on what the player
/// wanted. Every third video of the day pays two, and the meter under the
/// button says how close the next double is, so there is always a reason for
/// one more.
///
/// [what] is the line naming the purchase ("One more guess").
Future<bool> offerBananas(
  BuildContext context, {
  required String userId,
  required BananaUse use,
  required String what,
  String? title,
  String? dayKey,
  String? game,
}) async {
  final wallet = BananaWallet.instance;
  unawaited(wallet.refresh(userId));
  if (wallet.canWatch) {
    // Start fetching a video while the sheet animates in.
    unawaited(Future(() => wallet.watchWarm(userId)));
  }
  final spent = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => SheetFrame(
      title: title ?? AppLocalizations.of(context).bananaSheetTitle,
      showClose: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: _BananaPanel(
        userId: userId,
        use: use,
        what: what,
        dayKey: dayKey,
        game: game,
      ),
    ),
  );
  return spent == true;
}

/// The wallet on its own, from the bananas pill: the balance, what bananas
/// get you, and the ways to earn more. Nothing is being bought.
Future<void> showBananaWallet(BuildContext context, {required String userId}) {
  final wallet = BananaWallet.instance;
  unawaited(wallet.refresh(userId));
  wallet.watchWarm(userId);
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => SheetFrame(
      title: AppLocalizations.of(context).bananaSheetTitle,
      showClose: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: _BananaPanel(userId: userId),
    ),
  );
}

class _BananaPanel extends StatefulWidget {
  const _BananaPanel({
    required this.userId,
    this.use,
    this.what,
    this.dayKey,
    this.game,
  });

  final String userId;

  /// Null: the wallet on its own ([showBananaWallet]).
  final BananaUse? use;
  final String? what;
  final String? dayKey;
  final String? game;

  @override
  State<_BananaPanel> createState() => _BananaPanelState();
}

class _BananaPanelState extends State<_BananaPanel>
    with SingleTickerProviderStateMixin {
  final _wallet = BananaWallet.instance;
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _busy = false;
  int _gained = 0;
  int _popKey = 0;

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_changed);
  }

  @override
  void dispose() {
    _wallet.removeListener(_changed);
    _pop.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  int get _cost => widget.use?.cost ?? 1;

  Future<void> _spend() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _wallet.spend(
        widget.userId,
        widget.use!,
        dayKey: widget.dayKey,
        game: widget.game,
      );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final s = e.toString();
      if (s.contains('LIMIT')) AppToast.of(context).show(l10n.bananaLimit);
      if (!s.contains('NO_BANANAS') && !s.contains('LIMIT')) {
        // NOT_NEEDED / ALREADY_FINISHED: nothing to buy any more. Close and
        // let the caller re-read its state.
        Navigator.of(context).pop(false);
      }
    }
  }

  Future<void> _celebrate(int gained) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _gained = gained;
      _popKey++;
    });
    await _pop.forward(from: 0);
  }

  Future<void> _watch() async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    setState(() => _busy = true);
    final gained = await _wallet.watchAd(widget.userId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (gained == 0) {
      // Either skipped (say nothing), no video, or the credit is late.
      if (_wallet.lastOutcome == WatchOutcome.noVideo) {
        toast.show(l10n.bananaNoVideo);
      } else if (_wallet.lastOutcome == WatchOutcome.late) {
        toast.show(l10n.bananaLate);
      }
      return;
    }
    await _celebrate(gained);
    // The loop's payoff: what they came for, without another tap.
    if (mounted && widget.use != null && _wallet.balance >= _cost) {
      await _spend();
    }
  }

  Future<void> _free() async {
    setState(() => _busy = true);
    try {
      if (await _wallet.claimFree(widget.userId) && mounted) {
        await _celebrate(1);
      }
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final w = _wallet;
    final enough = w.balance >= _cost;
    final bonusNext = w.nextBonusIn == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              BananaGlyph(
                size: 72,
                popKey: _popKey,
                waving: w.freeReady && !_busy,
              ),
              Positioned(
                top: -6,
                right: -34,
                child: AnimatedBuilder(
                  animation: _pop,
                  builder: (context, _) {
                    final t = _pop.value;
                    if (_gained == 0 || !_pop.isAnimating) {
                      return const SizedBox.shrink();
                    }
                    return Transform.translate(
                      offset: Offset(0, -22 * t),
                      child: Opacity(
                        opacity: (1 - t * t).clamp(0.0, 1.0),
                        child: _Chip(text: l10n.bananaGot(_gained)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.bananaBalance(w.balance),
          textAlign: TextAlign.center,
          style: theme.displaySmall.copyWith(color: theme.ink),
        ),
        const SizedBox(height: 4),
        if (widget.what != null)
          Text(
            widget.what!,
            textAlign: TextAlign.center,
            style: theme.body.copyWith(color: theme.inkSoft),
          )
        else
          const _WhatTheyBuy(),
        const SizedBox(height: 20),
        // Always there when something is being bought, so the price is: it
        // waits, disabled, until the wallet covers it.
        if (widget.use != null)
          SheetActionButton(
            label: l10n.bananaUse(_cost),
            tonal: !enough,
            busy: _busy && enough,
            onTap: _busy || !enough ? null : _spend,
          ),
        if (w.canWatch) ...[
          if (widget.use != null) const SizedBox(height: 10),
          if (w.adsLeft > 0) ...[
            SheetActionButton(
              label: l10n.bananaWatch(bonusNext ? 2 : 1),
              icon: CupertinoIcons.play_fill,
              tonal: enough && widget.use != null,
              busy: _busy && !(enough && widget.use != null),
              onTap: _busy ? null : _watch,
            ),
            const SizedBox(height: 10),
            _BonusMeter(left: w.nextBonusIn),
            const SizedBox(height: 6),
            Text(
              l10n.bananaBonusIn(w.nextBonusIn),
              textAlign: TextAlign.center,
              style: theme.caption.copyWith(
                color: bonusNext ? theme.accent : theme.inkMuted,
              ),
            ),
          ] else
            Text(
              l10n.bananaAdsDone,
              textAlign: TextAlign.center,
              style: theme.caption.copyWith(color: theme.inkMuted),
            ),
        ] else if (!w.childAccount) ...[
          if (widget.use != null) const SizedBox(height: 14),
          Text(
            l10n.bananaPhoneOnly,
            textAlign: TextAlign.center,
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
          const SizedBox(height: 10),
          SheetActionButton(
            label: l10n.appOnlyGetApp,
            tonal: enough,
            onTap: () => LinkOpener.openExternal(kDownloadPageUrl),
          ),
        ],
        // Today's free banana: every account and every platform, children
        // included (it is the videos they are kept from, not bananas).
        if (w.freeReady) ...[
          const SizedBox(height: 14),
          SheetActionButton(
            label: l10n.bananaFree,
            icon: CupertinoIcons.gift_fill,
            tonal: true,
            onTap: _busy ? null : _free,
          ),
        ],
        const SizedBox(height: 10),
        SheetActionButton(
          label: l10n.bananasShopGetMore,
          icon: CupertinoIcons.bag_fill,
          tonal: true,
          onTap: () => showBananaShop(context),
        ),
        // A child's open asks ("waiting for a grown-up"), with take-back.
        // Renders nothing when there are none.
        if (w.childAccount) ...[
          const SizedBox(height: 14),
          BananaRequestsStrip(userId: widget.userId),
        ],
      ],
    );
  }
}

/// Three dots: how close the next double-banana video is.
class _BonusMeter extends StatelessWidget {
  const _BonusMeter({required this.left});

  /// 1..3 videos until the double one.
  final int left;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Two plain dots for the videos that pay one, then a "×2" chip for the
    // one that pays double. Dots fill as videos are watched; the chip lights
    // up when the next video is the double one. (Three bare dots, the last
    // one tinted, read as a page indicator sitting on step 3.)
    final watched = 3 - left;
    final next = left == 1;
    final d = MotionScope.of(context).d(const Duration(milliseconds: 250));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 2; i++)
          AnimatedContainer(
            duration: d,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: i < watched
                  ? theme.accent
                  : theme.inkMuted.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
          ),
        AnimatedContainer(
          duration: d,
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: next ? theme.accent : Colors.transparent,
            border: Border.all(
              color: next ? theme.accent : theme.inkMuted.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '×2',
            style: theme.caption.copyWith(
              color: next ? theme.accentInk : theme.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.success,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: theme.body.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The wallet's list of what a banana gets you.
class _WhatTheyBuy extends StatelessWidget {
  const _WhatTheyBuy();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final rows = [
      (CupertinoIcons.number, l10n.bananaForGuess),
      (CupertinoIcons.lightbulb_fill, l10n.bananaForHint),
      (CupertinoIcons.arrow_uturn_left, l10n.bananaForUndo),
      (CupertinoIcons.bolt_fill, l10n.bananaForContinue),
      (CupertinoIcons.flame_fill, l10n.streakSaveTitle),
    ];
    return Column(
      children: [
        const SizedBox(height: 6),
        for (final (icon, label) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: theme.accent),
                const SizedBox(width: 8),
                Text(label, style: theme.body.copyWith(color: theme.inkSoft)),
              ],
            ),
          ),
      ],
    );
  }
}
