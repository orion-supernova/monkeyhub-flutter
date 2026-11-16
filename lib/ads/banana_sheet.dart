import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/link_opener.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../update/update_destination.dart' show kDownloadPageUrl;
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/sheet_kit.dart' show SheetActionButton, SheetFrame;
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

class _BananaPanel extends StatefulWidget {
  const _BananaPanel({
    required this.userId,
    required this.use,
    required this.what,
    this.dayKey,
    this.game,
  });

  final String userId;
  final BananaUse use;
  final String what;
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

  int get _cost => widget.use.cost;

  Future<void> _spend() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _wallet.spend(
        widget.userId,
        widget.use,
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
    setState(() => _gained = gained);
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
    if (mounted && _wallet.balance >= _cost) await _spend();
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
    final calm = MotionScope.of(context).calm;
    final w = _wallet;
    final enough = w.balance >= _cost;
    final bonusNext = w.nextBonusIn == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Center(
          child: AnimatedBuilder(
            animation: _pop,
            builder: (context, child) {
              final t = _pop.value;
              final k = calm ? 1.0 : 1 + 0.35 * Curves.elasticOut.transform(t) * (1 - t);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.scale(scale: k, child: child),
                  if (_gained > 0 && _pop.isAnimating)
                    Positioned(
                      top: -18 * t,
                      right: -30,
                      child: Opacity(
                        opacity: (1 - t).clamp(0.0, 1.0),
                        child: _Chip(text: l10n.bananaGot(_gained)),
                      ),
                    ),
                ],
              );
            },
            child: const Text('🍌', style: TextStyle(fontSize: 64)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.bananaBalance(w.balance),
          textAlign: TextAlign.center,
          style: theme.displaySmall.copyWith(color: theme.ink),
        ),
        const SizedBox(height: 4),
        Text(
          widget.what,
          textAlign: TextAlign.center,
          style: theme.body.copyWith(color: theme.inkSoft),
        ),
        const SizedBox(height: 20),
        if (enough)
          SheetActionButton(
            label: l10n.bananaUse(_cost),
            busy: _busy,
            onTap: _busy ? null : _spend,
          ),
        if (w.canWatch) ...[
          if (enough) const SizedBox(height: 10),
          if (w.adsLeft > 0) ...[
            SheetActionButton(
              label: l10n.bananaWatch(bonusNext ? 2 : 1),
              icon: CupertinoIcons.play_fill,
              tonal: enough,
              busy: _busy && !enough,
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
          if (w.freeReady) ...[
            const SizedBox(height: 14),
            SheetActionButton(
              label: l10n.bananaFree,
              icon: CupertinoIcons.gift_fill,
              tonal: true,
              onTap: _busy ? null : _free,
            ),
          ],
        ] else if (!w.childAccount) ...[
          if (enough) const SizedBox(height: 14),
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
    final filled = 3 - left;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: MotionScope.of(context).d(const Duration(milliseconds: 250)),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == 2 ? 22 : 14,
            height: 8,
            decoration: BoxDecoration(
              color: i < filled
                  ? theme.accent
                  : i == 2
                  ? theme.accent.withValues(alpha: 0.25)
                  : theme.inkMuted.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(99),
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
