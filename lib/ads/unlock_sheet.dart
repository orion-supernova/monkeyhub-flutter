import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/convex_client.dart';
import '../chat_games/match_copy.dart' show chatGameName;
import '../fight/core/characters/roster.dart' show roster;
import '../games/catalog.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/sheet_kit.dart' show SheetFrame;
import '../widgets/action_buttons.dart' show SheetActionButton;
import 'banana_shop.dart';
import 'banana_wallet.dart';

/// Opens the unlock sheet for catalog item [itemId] (`fighter.golem`,
/// `game.chess`, `bundle.fist`, ...). Resolves true when the item is owned
/// afterwards (bought here, or already owned), so the caller proceeds.
///
/// An adult sees the price, their balance and what is left after, a bundle
/// hint, the free first pick when it is still unused, and "Get bananas" when
/// short. A child sees the Ask variant: a sticker, an optional note and "Ask
/// a grown-up"; they only unlock for themselves when a guardian let their own
/// bananas buy unlocks. [reason] is a line of context from the caller ("Unlock
/// this fighter to use them in online fights.").
///
/// Design: docs/design/bananas-and-unlocks.html, Screens.
Future<bool> showUnlockSheet(
  BuildContext context,
  String itemId, {
  String? reason,
}) async {
  final wallet = BananaWallet.instance;
  final userId = wallet.userId;
  if (userId == null || catalogItem(itemId) == null) return false;
  if (wallet.loaded && wallet.ownsItem(itemId)) return true;
  unawaited(wallet.refresh(userId));
  final l10n = AppLocalizations.of(context);
  final name = unlockItemName(l10n, itemId);
  final child = wallet.childAccount;
  final done = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => SheetFrame(
      title: child
          ? l10n.bananasSheetAskTitle(name)
          : l10n.bananasSheetUnlockTitle(name),
      showClose: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: _UnlockPanel(userId: userId, itemId: itemId, reason: reason),
    ),
  );
  return done == true || wallet.ownsItem(itemId);
}

// ── What an item is called and looks like ───────────────────────────────────

/// The display name of catalog item [id], localised.
String unlockItemName(AppLocalizations l10n, String id) {
  final dot = id.indexOf('.');
  final kind = dot < 0 ? id : id.substring(0, dot);
  final key = dot < 0 ? '' : id.substring(dot + 1);
  switch (kind) {
    case 'fighter':
      for (final c in roster) {
        if (c.key == key) return c.name;
      }
      return key;
    case 'stage':
      return switch (key) {
        'temple' => l10n.bananasStageTemple,
        'neon' => l10n.bananasStageNeon,
        'aurora' => l10n.bananasStageAurora,
        'canyon' => l10n.bananasStageCanyon,
        'deck' => l10n.bananasStageDeck,
        _ => key,
      };
    case 'look':
      return key == 'pixel' ? l10n.fightLookPixel : l10n.fightLookPainted;
    case 'game':
      return chatGameName(l10n, key);
    case 'bundle':
      return switch (key) {
        'animals' => l10n.bananasBundleAnimals,
        'legends' => l10n.bananasBundleLegends,
        'stages' => l10n.bananasBundleStages,
        'looks' => l10n.bananasBundleLooks,
        'fist' => l10n.bananasBundleFist,
        'gamenight' => l10n.bananasBundleGamenight,
        _ => key,
      };
  }
  return id;
}

/// A glyph for [id], for the preview tile and the shop rows.
String unlockItemEmoji(String id) {
  final item = catalogItem(id);
  switch (item?.kind) {
    case CatalogKind.fighter:
      return item!.price >= 90 ? '\u{1F409}' : '\u{1F43E}';
    case CatalogKind.stage:
      return '\u{1F3DE}\u{FE0F}';
    case CatalogKind.look:
      return '\u{1F3A8}';
    case CatalogKind.game:
      return switch (id) {
        'game.checkers' => '\u{1F534}',
        'game.reversi' => '\u{26AB}',
        'game.chess' => '\u{265F}\u{FE0F}',
        'game.imposter' => '\u{1F575}\u{FE0F}',
        'game.liarsdice' => '\u{1F3B2}',
        _ => '\u{1F3C1}',
      };
    case CatalogKind.bundle:
      return '\u{1F381}';
    case null:
      return '\u{1F34C}';
  }
}

/// Whether the free first pick may be spent on [itemId].
bool firstPickEligible(String itemId) {
  final item = catalogItem(itemId);
  if (item == null) return false;
  return (item.kind == CatalogKind.fighter || item.kind == CatalogKind.stage) &&
      BananaWallet.instance.priceOf(itemId) <= kFirstPickMax;
}

/// A server refusal's code out of whatever was thrown.
String unlockErrorCode(Object e) {
  final s = e.toString();
  for (final c in const [
    'NO_BANANAS',
    'OWNED',
    'FIRST_PICK_USED',
    'NOT_ELIGIBLE',
    'CHILD_ASK',
    'NOT_CHILD',
    'ASK_OFF',
    'TOO_MANY',
    'ALREADY_ASKED',
    'COOLDOWN',
    'UNKNOWN_ITEM',
  ]) {
    if (s.contains(c)) return c;
  }
  return '';
}

// ── The panel ───────────────────────────────────────────────────────────────

const _stickers = ['\u{1F64F}', '\u{1F97A}', '\u{1F382}', '\u{2B50}'];

class _UnlockPanel extends StatefulWidget {
  const _UnlockPanel({
    required this.userId,
    required this.itemId,
    this.reason,
  });

  final String userId;
  final String itemId;
  final String? reason;

  @override
  State<_UnlockPanel> createState() => _UnlockPanelState();
}

class _UnlockPanelState extends State<_UnlockPanel>
    with SingleTickerProviderStateMixin {
  final _wallet = BananaWallet.instance;
  final _note = TextEditingController();
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _busy = false;
  bool _won = false;
  bool _asked = false;
  int _sticker = 0;

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_changed);
    if (_wallet.childAccount) unawaited(_loadAsked());
  }

  @override
  void dispose() {
    _wallet.removeListener(_changed);
    _note.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// One read: has this child already asked for this item?
  Future<void> _loadAsked() async {
    try {
      final res = await ConvexBackend.instance.query('bananaRequests:mine', {
        'userId': widget.userId,
      });
      if (res is! List || !mounted) return;
      final asked = res.any(
        (r) => r is Map && r['item'] == widget.itemId && r['status'] == 'open',
      );
      if (asked) setState(() => _asked = true);
    } catch (_) {
      // Advisory: the ask itself answers ALREADY_ASKED.
    }
  }

  int get _price => _wallet.priceOf(widget.itemId);

  Future<void> _celebrate() async {
    HapticFeedback.heavyImpact();
    setState(() => _won = true);
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!calm) await _burst.forward(from: 0);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _unlock({bool firstPick = false}) async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    setState(() => _busy = true);
    try {
      await _wallet.unlock(widget.userId, widget.itemId, firstPick: firstPick);
      if (!mounted) return;
      await _celebrate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      switch (unlockErrorCode(e)) {
        case 'OWNED':
          unawaited(_wallet.refresh(widget.userId));
          Navigator.of(context).pop(true);
        case 'NO_BANANAS':
          unawaited(_wallet.refresh(widget.userId));
        default:
          toast.show(l10n.bananasSheetFailed);
      }
    }
  }

  Future<void> _ask() async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final note = _note.text.trim();
      await ConvexBackend.instance.mutation('bananaRequests:ask', {
        'userId': widget.userId,
        'item': widget.itemId,
        if (note.isNotEmpty) 'note': note,
        'sticker': _stickers[_sticker],
      });
      HapticFeedback.mediumImpact();
      toast.show(l10n.bananasAskSent);
      if (mounted) nav.pop(false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      switch (unlockErrorCode(e)) {
        case 'ALREADY_ASKED':
          setState(() => _asked = true);
        case 'TOO_MANY':
          toast.show(l10n.bananasAskTooMany);
        case 'COOLDOWN':
          toast.show(l10n.bananasAskCooldown);
        case 'ASK_OFF':
          toast.show(l10n.bananasAskOff);
        case 'OWNED':
          nav.pop(true);
        default:
          toast.show(l10n.bananasSheetFailed);
      }
    }
  }

  Future<void> _getBananas() async {
    await showBananaShop(context);
    if (mounted) unawaited(_wallet.refresh(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final id = widget.itemId;
    final price = _price;
    final balance = _wallet.balance;
    final child = _wallet.childAccount;
    final short = balance < price;

    final body = <Widget>[
      const SizedBox(height: 4),
      _Preview(itemId: id, won: _won, burst: _burst),
      const SizedBox(height: 14),
      Text(
        _won
            ? l10n.bananasSheetUnlocked(unlockItemName(l10n, id))
            : (child ? l10n.bananasAskBody : l10n.bananasSheetForever),
        textAlign: TextAlign.center,
        style: theme.body.copyWith(color: theme.inkSoft),
      ),
      if (widget.reason != null && !_won) ...[
        const SizedBox(height: 6),
        Text(
          widget.reason!,
          textAlign: TextAlign.center,
          style: theme.caption.copyWith(color: theme.inkMuted),
        ),
      ],
      const SizedBox(height: 18),
    ];

    if (!_won) {
      if (child) {
        body.addAll(_childBody(context, price, balance));
      } else {
        body.addAll(_adultBody(context, price, balance, short));
      }
    }
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: theme.body,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: body,
        ),
      ),
    );
  }

  List<Widget> _adultBody(
    BuildContext context,
    int price,
    int balance,
    bool short,
  ) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final id = widget.itemId;
    final bundle = bundleFor(id);
    final bundlePrice = bundle == null ? 0 : _wallet.priceOf(bundle.id);
    final showBundle =
        bundle != null && bundlePrice > 0 && !_wallet.ownsItem(bundle.id);
    final firstPick = _wallet.firstPickReady && firstPickEligible(id);
    return [
      _BalanceRow(label: l10n.bananasSheetYourBananas, value: '\u{1F34C} $balance'),
      const SizedBox(height: 6),
      Text(
        short
            ? l10n.bananasSheetShort(price - balance)
            : l10n.bananasSheetAfter(balance - price),
        textAlign: TextAlign.center,
        style: theme.caption.copyWith(
          color: short ? theme.danger : theme.inkMuted,
        ),
      ),
      const SizedBox(height: 16),
      if (firstPick) ...[
        SheetActionButton(
          label: l10n.bananasSheetFirstPick,
          icon: CupertinoIcons.gift_fill,
          busy: _busy,
          onTap: _busy ? null : () => _unlock(firstPick: true),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.bananasSheetFirstPickNote,
          textAlign: TextAlign.center,
          style: theme.caption.copyWith(color: theme.inkMuted),
        ),
        const SizedBox(height: 12),
      ],
      if (short)
        SheetActionButton(
          label: l10n.bananasSheetGetBananas,
          tonal: firstPick,
          onTap: _busy ? null : _getBananas,
        )
      else
        SheetActionButton(
          label: l10n.bananasUnlockFor(price),
          tonal: firstPick,
          busy: _busy && !firstPick,
          onTap: _busy ? null : _unlock,
        ),
      if (showBundle) ...[
        const SizedBox(height: 12),
        Text(
          l10n.bananasSheetBundleHint(
            bundle.members.length,
            unlockItemName(l10n, bundle.id),
            bundlePrice,
          ),
          textAlign: TextAlign.center,
          style: theme.caption.copyWith(color: theme.inkMuted),
        ),
      ],
    ];
  }

  List<Widget> _childBody(BuildContext context, int price, int balance) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final rules = _wallet.child;
    if (rules != null && !rules.ask && !_wallet.childMaySpendOnUnlocks) {
      return [
        Text(
          l10n.bananasAskOff,
          textAlign: TextAlign.center,
          style: theme.caption.copyWith(color: theme.inkMuted),
        ),
      ];
    }
    final canOwn = _wallet.childMaySpendOnUnlocks && balance >= price;
    return [
      if (_asked)
        SheetActionButton(label: l10n.bananasAskWaiting, onTap: null)
      else if (rules == null || rules.ask) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _stickers.length; i++)
              _StickerChip(
                emoji: _stickers[i],
                selected: i == _sticker,
                onTap: () => setState(() => _sticker = i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _NoteField(controller: _note, hint: l10n.bananasAskNoteHint),
        const SizedBox(height: 14),
        SheetActionButton(
          label: l10n.bananasAskButton,
          busy: _busy,
          onTap: _busy ? null : _ask,
        ),
      ],
      if (_wallet.childMaySpendOnUnlocks) ...[
        const SizedBox(height: 14),
        Text(
          l10n.bananasAskOwn(balance, price),
          textAlign: TextAlign.center,
          style: theme.caption.copyWith(color: theme.inkMuted),
        ),
        if (canOwn) ...[
          const SizedBox(height: 10),
          SheetActionButton(
            label: l10n.bananasAskOwnButton,
            tonal: true,
            onTap: _busy ? null : _unlock,
          ),
        ],
      ],
    ];
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// The item's tile, with the lock that pops open and the banana burst when it
/// is won. Transforms and opacity only: nothing here blurs or repaints a
/// layer under motion.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.itemId,
    required this.won,
    required this.burst,
  });

  final String itemId;
  final bool won;
  final AnimationController burst;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accentSoft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    unlockItemEmoji(itemId),
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(fontSize: 44, height: 1),
                  ),
                ),
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: _LockBadge(open: won),
                ),
              ],
            ),
          ),
          if (won)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: burst,
                  builder: (context, _) => _BananaBurst(t: burst.value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(open),
      tween: Tween(begin: open ? 0.6 : 1, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: open ? theme.success : theme.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(
          open ? CupertinoIcons.lock_open_fill : CupertinoIcons.lock_fill,
          size: 15,
          color: open ? Colors.white : theme.inkSoft,
        ),
      ),
    );
  }
}

/// Eight bananas thrown up and out from the tile, falling away as they fade.
class _BananaBurst extends StatelessWidget {
  const _BananaBurst({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutCubic.transform(t);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < 8; i++)
          Builder(
            builder: (context) {
              final a = -math.pi / 2 + (i - 3.5) * 0.42;
              final r = 38 + 46 * e;
              final dx = math.cos(a) * r * 1.4;
              final dy = math.sin(a) * r + 30 * t * t;
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.rotate(
                  angle: (i.isEven ? 1 : -1) * t * 2.2,
                  child: Opacity(
                    opacity: (1 - t * t).clamp(0.0, 1.0),
                    child: const Text(
                      '\u{1F34C}',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontSize: 22, height: 1),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.body.copyWith(color: theme.inkSoft)),
        Text(value, style: theme.bodyEmph.copyWith(color: theme.ink)),
      ],
    );
  }
}

class _StickerChip extends StatelessWidget {
  const _StickerChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.accent : theme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          emoji,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(fontSize: 24, height: 1),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        maxLength: 80,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        style: theme.body.copyWith(color: theme.ink),
        cursorColor: theme.accent,
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: theme.body.copyWith(color: theme.inkMuted),
        ).copyWith(counterText: ''),
      ),
    );
  }
}
