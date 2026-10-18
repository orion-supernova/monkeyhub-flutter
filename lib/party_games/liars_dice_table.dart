import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_games/match_copy.dart';
import '../chat_games/match_face.dart';
import '../data/matches_store.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../games/game_canvas.dart' show digitOfKey;
import '../models/chat_match.dart';
import '../platform.dart' show isPhysicalKeyboardPlatform;
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/seat_palette.dart';
import '../widgets/ios_kit.dart';
import 'dice.dart';
import 'party_kit.dart';
import 'party_views.dart';

/// LIAR'S DICE at the table: everyone's cups along the top, the standing bid
/// in the middle, your own dice under it, and on your turn the bid picker.
///
/// There is no pause between rounds on the server: a call ends a round and
/// the next one's clock is already running. So the call's reveal (every die,
/// the ones that counted lit, who loses one) takes the bid's place for
/// [revealFor], over the new round, and goes on a tap or when it runs out.
/// The picker under it is live the whole time; whoever starts the next round
/// can bid without waiting for the show to end.
class LiarsDiceTable extends StatefulWidget {
  const LiarsDiceTable({
    super.key,
    required this.match,
    required this.controller,
    required this.viewerId,
    this.enabled = true,
    this.stage = false,
  });

  final ChatMatch match;
  final MatchController controller;
  final String viewerId;

  /// False while the 3-2-1 runs.
  final bool enabled;

  /// The desktop stage's middle: no faces along the top (they are in
  /// [LiarsDiceStagePanel] beside it), the rest centred, and the keys live.
  final bool stage;

  static const revealFor = Duration(seconds: 6);

  @override
  State<LiarsDiceTable> createState() => _LiarsDiceTableState();
}

class _LiarsDiceTableState extends State<LiarsDiceTable> {
  /// The picker's choice, for the standing bid it was made against.
  int _qty = 1;
  int _face = 2;
  String? _pickedFor;

  /// The reveal on show, and when it goes.
  int? _revealRound;
  Timer? _revealTimer;

  /// The newest reveal this screen has seen. One already standing when the
  /// screen opens is old news and is not replayed.
  int? _seenReveal;

  String? _secretRaw;
  LiarsDiceSecret? _secret;

  @override
  void initState() {
    super.initState();
    final v = _view;
    _seenReveal = v?.reveal?.round;
  }

  @override
  void didUpdateWidget(LiarsDiceTable old) {
    super.didUpdateWidget(old);
    final r = _view?.reveal;
    if (r != null && r.round != _seenReveal) {
      _seenReveal = r.round;
      _showReveal(r);
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  LiarsDiceView? get _view {
    final v = partyViewOf(widget.match);
    return v is LiarsDiceView ? v : null;
  }

  LiarsDiceSecret? get _mine {
    final raw = widget.controller.secret;
    if (raw != _secretRaw) {
      _secretRaw = raw;
      try {
        _secret = raw == null ? null : LiarsDiceSecret.fromJson(jsonDecode(raw));
      } catch (_) {
        _secret = null;
      }
    }
    return _secret;
  }

  void _showReveal(DiceReveal r) {
    final mySeat = widget.match.seatOf(widget.viewerId);
    if (r.loser == mySeat) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    _revealTimer?.cancel();
    setState(() => _revealRound = r.round);
    _revealTimer = Timer(LiarsDiceTable.revealFor, () {
      if (mounted) setState(() => _revealRound = null);
    });
  }

  void _dismissReveal() {
    _revealTimer?.cancel();
    setState(() => _revealRound = null);
  }

  /// Resets the picker to the smallest legal raise of [bid]: one face up, or
  /// one more die once the face is already 6. An opening bid starts at one of
  /// the face the player holds most of, the same modest bid the timer would
  /// make for them.
  void _resetPicker(LiarsDiceView v, DiceBid? bid, List<int> dice) {
    final key = '${v.round}:${v.bids.length}';
    if (_pickedFor == key) return;
    _pickedFor = key;
    if (bid == null) {
      _qty = 1;
      _face = _mostCommon(dice);
    } else if (bid.face == 1) {
      _qty = bid.qty + 1;
      _face = 1;
    } else if (bid.face < 6) {
      _qty = bid.qty;
      _face = bid.face + 1;
    } else {
      _qty = bid.qty + 1;
      _face = 6;
    }
  }

  static int _mostCommon(List<int> dice) {
    var best = 6;
    var bestN = -1;
    for (var face = 6; face >= 1; face--) {
      final n = dice.where((d) => d == face).length;
      if (n > bestN) {
        best = face;
        bestN = n;
      }
    }
    return best;
  }

  void _setQty(int qty, DiceBid? bid) {
    HapticFeedback.selectionClick();
    setState(() {
      _qty = qty;
      // The face may no longer be a raise at this quantity: move it up to
      // the first one that is.
      if (bid != null && !bid.raisedBy(_qty, _face)) {
        // Plain faces first: the 1s are the expensive bid, never the default.
        for (final f in const [2, 3, 4, 5, 6, 1]) {
          if (bid.raisedBy(_qty, f)) {
            _face = f;
            break;
          }
        }
      }
    });
  }

  /// Desktop keys on the viewer's turn: ↑ ↓ the quantity, ← → or 1–6 the
  /// face (only ever to a face that raises), Enter bids, L calls.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!plainKeyDown(event)) return KeyEventResult.ignored;
    final m = widget.match;
    final v = _view;
    if (v == null || !widget.enabled) return KeyEventResult.ignored;
    final mySeat = m.seatOf(widget.viewerId);
    final myTurn = m.status == MatchStatus.active &&
        !v.over &&
        v.turn == mySeat &&
        mySeat >= 0;
    if (!myTurn || widget.controller.pendingAction != null) {
      return KeyEventResult.ignored;
    }
    final bid = v.bid;
    final key = event.logicalKey;
    bool canFace(int f) => bid == null || bid.raisedBy(_qty, f);
    void face(int f) {
      if (f == _face || !canFace(f)) return;
      HapticFeedback.selectionClick();
      setState(() => _face = f);
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_qty < v.totalDice) _setQty(_qty + 1, bid);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final min = bid == null ? 1 : bid.minRaiseQty;
      if (_qty > min) _setQty(_qty - 1, bid);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final dir = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
      for (var f = _face + dir; f >= 1 && f <= 6; f += dir) {
        if (canFace(f)) {
          face(f);
          break;
        }
      }
      return KeyEventResult.handled;
    }
    final digit = digitOfKey(key);
    if (digit != null && digit >= 1 && digit <= 6) {
      face(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_qty <= v.totalDice && canFace(_face)) {
        widget.controller.act('bid:$_qty:$_face');
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyL && bid != null) {
      HapticFeedback.mediumImpact();
      widget.controller.act('liar');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final table = _table(context);
    if (!widget.stage) return table;
    return Focus(
      autofocus: isPhysicalKeyboardPlatform,
      onKeyEvent: _onKey,
      child: PartyStageBody(child: table),
    );
  }

  Widget _table(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = widget.match;
    final v = _view;
    if (v == null) return const SizedBox.shrink();
    final me = widget.viewerId;
    final mySeat = m.seatOf(me);
    final active = m.status == MatchStatus.active;
    final secret = _mine;
    final myDice = secret != null && secret.round == v.round
        ? secret.dice
        : const <int>[];
    final myTurn = active && !v.over && v.turn == mySeat && mySeat >= 0;
    final bid = v.bid;
    if (myTurn) _resetPicker(v, bid, myDice);
    final reveal = v.reveal;
    // Over on a call: that call is the ending, shown for good. Over because
    // players left: the last call is history, and the hands are shown below.
    final finalCall = v.over && reveal != null && reveal.round == v.round;
    final showReveal = reveal != null &&
        (finalCall || (!v.over && _revealRound == reveal.round));
    final motion = MotionScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.stage) ...[
          LiarsDiceSeats(match: m, view: v, viewerId: me, clock: widget.controller),
          const SizedBox(height: 14),
        ],
        AnimatedSize(
          duration: motion.d(theme.motionMed),
          curve: theme.motionCurve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: motion.d(theme.motionFast),
            child: showReveal
                ? GestureDetector(
                    key: ValueKey('reveal-${reveal.round}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: v.over ? null : _dismissReveal,
                    child: _RevealPanel(
                      match: m,
                      reveal: reveal,
                      viewerId: me,
                    ),
                  )
                : _BidPanel(
                    key: ValueKey('bid-${v.round}'),
                    match: m,
                    view: v,
                    viewerId: me,
                  ),
          ),
        ),
        if (mySeat >= 0 && !v.over && !v.isOut(mySeat)) ...[
          const SizedBox(height: 12),
          PartyPanel(
            child: Column(
              children: [
                Text(
                  sentenceCaseOf(context, l10n.chatGameLdYourDice),
                  style: groupedMetaStyle(theme).copyWith(
                    color: theme.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                myDice.isEmpty
                    ? DiceRow(
                        dice: List.filled(v.counts[mySeat], 0),
                        size: 44,
                        tones: List.filled(v.counts[mySeat], DieTone.hidden),
                      )
                    : DiceRow(
                        dice: myDice,
                        size: 44,
                        // The standing bid's dice, lit in your own hand:
                        // what you know for certain toward it.
                        tones: [
                          for (final d in myDice)
                            bid != null && diceCounts(d, bid.face)
                                ? DieTone.hit
                                : DieTone.plain,
                        ],
                      ),
              ],
            ),
          ),
        ],
        if (myTurn) ...[
          const SizedBox(height: 12),
          _BidPicker(
            qty: _qty,
            face: _face,
            bid: bid,
            total: v.totalDice,
            busy: widget.controller.pendingAction != null,
            enabled: widget.enabled,
            onQty: (q) => _setQty(q, bid),
            onFace: (f) {
              HapticFeedback.selectionClick();
              setState(() => _face = f);
            },
            onBid: () => widget.controller.act('bid:$_qty:$_face'),
            onLiar: bid == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    widget.controller.act('liar');
                  },
          ),
          if (widget.stage && isPhysicalKeyboardPlatform) ...[
            const SizedBox(height: 10),
            PartyCaption(l10n.partyLdKeys),
          ],
        ],
        if (v.over && !finalCall && v.dice != null) ...[
          const SizedBox(height: 12),
          _FinalHands(match: m, view: v, viewerId: me),
        ],
      ],
    );
  }
}

/// The standing bid, large, and the one rule everyone forgets.
class _BidPanel extends StatelessWidget {
  const _BidPanel({
    super.key,
    required this.match,
    required this.view,
    required this.viewerId,
  });

  final ChatMatch match;
  final LiarsDiceView view;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final bid = view.bid;
    final mySeat = match.seatOf(viewerId);
    final myTurn = match.status == MatchStatus.active && view.turn == mySeat;
    final big = theme.displayLarge.copyWith(
      fontSize: 56,
      height: 1,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final String by;
    if (bid == null) {
      by = myTurn ? l10n.chatGameLdOpenPrompt : l10n.chatGameLdNoBid;
    } else if (bid.auto) {
      by = l10n.chatGameLdTimedOut(seatName(l10n, match, bid.seat, viewerId));
    } else {
      by = bid.seat == mySeat
          ? l10n.chatGameLdYourBid
          : l10n.chatGameLdBidBy(seatName(l10n, match, bid.seat, viewerId));
    }
    return PartyPanel(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          Text(
            l10n.chatGameLdRoundDice(view.totalDice, view.round),
            style: groupedMetaStyle(theme).copyWith(
              color: theme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: bid == null
                ? Center(
                    child: Icon(
                      CupertinoIcons.cube,
                      size: 44,
                      color: theme.ink.withValues(alpha: 0.18),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${bid.qty}', style: big),
                      const SizedBox(width: 10),
                      Text(
                        '×',
                        style: big.copyWith(
                          fontSize: 34,
                          color: theme.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DieFace(face: bid.face, size: 54),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            sentenceCaseOf(context, by),
            textAlign: TextAlign.center,
            style: groupedTitleStyle(theme).copyWith(
              fontWeight: FontWeight.w600,
              color: myTurn && bid == null ? theme.accent : theme.ink,
            ),
          ),
          if (myTurn && bid != null) ...[
            const SizedBox(height: 2),
            PartyCaption(l10n.chatGameLdPrompt, color: theme.accent),
          ],
          const SizedBox(height: 6),
          PartyCaption(
            bid?.face == 1 ? l10n.chatGameLdOnesOnly : l10n.chatGameLdOnesWild,
          ),
        ],
      ),
    );
  }
}

/// Quantity stepper, face chips, and the two buttons. Only raises are
/// enabled: a face chip that would not beat the standing bid at this
/// quantity is greyed and does nothing.
class _BidPicker extends StatelessWidget {
  const _BidPicker({
    required this.qty,
    required this.face,
    required this.bid,
    required this.total,
    required this.busy,
    required this.enabled,
    required this.onQty,
    required this.onFace,
    required this.onBid,
    this.onLiar,
  });

  final int qty;
  final int face;
  final DiceBid? bid;
  final int total;
  final bool busy;
  final bool enabled;
  final ValueChanged<int> onQty;
  final ValueChanged<int> onFace;
  final VoidCallback onBid;
  final VoidCallback? onLiar;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final b = bid;
    final minQty = b == null ? 1 : b.minRaiseQty;
    final legal = qty <= total && (b == null || b.raisedBy(qty, face));
    final can = enabled && !busy;
    final label = groupedMetaStyle(theme).copyWith(
      color: theme.inkMuted,
      fontWeight: FontWeight.w600,
    );
    return PartyPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(sentenceCaseOf(context, l10n.chatGameLdQuantity), style: label),
              ),
              _StepButton(
                key: const ValueKey('ld_qty_minus'),
                icon: CupertinoIcons.minus,
                semanticLabel: l10n.chatGameLdFewer,
                onTap: can && qty > minQty ? () => onQty(qty - 1) : null,
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '$qty',
                  key: const ValueKey('ld_qty'),
                  textAlign: TextAlign.center,
                  style: theme.displayMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _StepButton(
                key: const ValueKey('ld_qty_plus'),
                icon: CupertinoIcons.plus,
                semanticLabel: l10n.chatGameLdMore,
                onTap: can && qty < total ? () => onQty(qty + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(sentenceCaseOf(context, l10n.chatGameLdFace), style: label),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var f = 1; f <= 6; f++)
                _FaceChip(
                  key: ValueKey('ld_face_$f'),
                  face: f,
                  selected: f == face,
                  onTap: can && (b == null || b.raisedBy(qty, f))
                      ? () => onFace(f)
                      : null,
                ),
            ],
          ),
          if (b != null && (b.face == 1 || face == 1)) ...[
            const SizedBox(height: 10),
            PartyCaption(l10n.partyLdAcesRule),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (onLiar != null) ...[
                Expanded(
                  child: SheetActionButton(
                    key: const ValueKey('ld_liar'),
                    label: l10n.chatGameLdLiar,
                    destructive: true,
                    haptic: false,
                    onTap: can ? onLiar : null,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: SheetActionButton(
                  key: const ValueKey('ld_bid'),
                  label: '${sentenceCaseOf(context, l10n.chatGameLdBid)}  $qty × $face',
                  tonal: onLiar != null,
                  busy: busy,
                  onTap: can && legal ? onBid : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final on = onTap != null;
    final disc = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.ink.withValues(alpha: on ? 0.09 : 0.04),
      ),
      child: Icon(icon, size: 18, color: on ? theme.ink : theme.inkMuted),
    );
    return Semantics(
      button: true,
      enabled: on,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: on
            ? SpringPress(
                onTap: onTap,
                haptic: false,
                focusShape: FocusRingShape.circle,
                child: disc,
              )
            : disc,
      ),
    );
  }
}

class _FaceChip extends StatelessWidget {
  const _FaceChip({
    super.key,
    required this.face,
    required this.selected,
    this.onTap,
  });

  final int face;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final on = onTap != null;
    final chip = AnimatedContainer(
      duration: MotionScope.of(context).d(theme.motionFast),
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: selected ? theme.accent.withValues(alpha: 0.16) : Colors.transparent,
        border: Border.all(
          color: selected ? theme.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Opacity(
        opacity: on || selected ? 1 : 0.3,
        child: DieFace(face: face, size: 32),
      ),
    );
    return Semantics(
      button: true,
      enabled: on,
      selected: selected,
      label: '$face',
      child: ExcludeSemantics(
        child: on
            ? SpringPress(onTap: onTap, haptic: false, child: chip)
            : chip,
      ),
    );
  }
}

/// The last call, shown: holds or busted, how many there were, every hand
/// with the dice that counted lit, and who pays for it.
class _RevealPanel extends StatelessWidget {
  const _RevealPanel({
    required this.match,
    required this.reveal,
    required this.viewerId,
  });

  final ChatMatch match;
  final DiceReveal reveal;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final r = reveal;
    final mySeat = match.seatOf(viewerId);
    final tone = r.holds ? theme.success : theme.danger;
    final caller = seatName(l10n, match, r.caller, viewerId);
    return PartyPanel(
      tint: tone.withValues(alpha: 0.10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sentenceCaseOf(
              context,
              r.auto ? l10n.chatGameLdTimedOut(caller) : l10n.chatGameLdCalled(caller),
            ),
            textAlign: TextAlign.center,
            style: groupedMetaStyle(theme).copyWith(
              color: theme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sentenceCaseOf(
              context,
              r.holds ? l10n.chatGameLdHolds : l10n.chatGameLdBusted,
            ),
            textAlign: TextAlign.center,
            style: theme.displayMedium.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${r.bid.qty} ×',
                style: groupedTitleStyle(theme).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              DieFace(face: r.bid.face, size: 22),
              const SizedBox(width: 10),
              Text(
                '·',
                style: groupedTitleStyle(theme).copyWith(color: theme.inkMuted),
              ),
              const SizedBox(width: 10),
              Text(
                sentenceCaseOf(context, l10n.chatGameLdThereWere(r.count)),
                style: groupedTitleStyle(theme).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < r.dice.length && i < match.seats.length; i++)
            if (r.dice[i].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HandRow(
                  match: match,
                  seat: i,
                  viewerId: viewerId,
                  dice: r.dice[i],
                  face: r.bid.face,
                  loser: i == r.loser,
                ),
              ),
          const SizedBox(height: 4),
          Text(
            sentenceCaseOf(
              context,
              r.loser == mySeat
                  ? l10n.chatGameLdYouLoseDie
                  : l10n.chatGameLdLosesDie(seatName(l10n, match, r.loser, viewerId)),
            ),
            textAlign: TextAlign.center,
            style: groupedTitleStyle(theme).copyWith(
              color: theme.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandRow extends StatelessWidget {
  const _HandRow({
    required this.match,
    required this.seat,
    required this.viewerId,
    required this.dice,
    this.face,
    this.loser = false,
  });

  final ChatMatch match;
  final int seat;
  final String viewerId;
  final List<int> dice;

  /// The bid's face, to light what counted; null draws them all plain.
  final int? face;
  final bool loser;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final s = match.seats[seat];
    return Row(
      children: [
        MatchFace(roomId: match.roomId, userId: s.userId, name: s.name, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            seatName(l10n, match, seat, viewerId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: groupedMetaStyle(theme).copyWith(
              color: loser ? theme.danger : theme.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DiceRow(
          dice: dice,
          size: 24,
          gap: 5,
          tones: face == null
              ? null
              : [
                  for (final d in dice)
                    diceCounts(d, face!) ? DieTone.hit : DieTone.miss,
                ],
        ),
      ],
    );
  }
}

/// Once it is over, every hand that was still on the table.
class _FinalHands extends StatelessWidget {
  const _FinalHands({
    required this.match,
    required this.view,
    required this.viewerId,
  });

  final ChatMatch match;
  final LiarsDiceView view;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final dice = view.dice!;
    final rows = [
      for (var i = 0; i < dice.length && i < match.seats.length; i++)
        if (dice[i].isNotEmpty) i,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return PartyPanel(
      child: Column(
        children: [
          for (final i in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _HandRow(
                match: match,
                seat: i,
                viewerId: viewerId,
                dice: dice[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Everyone at the table as faces, each with a cup of the dice they still
/// hold, the one to bid wearing the clock. Along the top on a phone, and at
/// the top of [LiarsDiceStagePanel] on the desktop stage.
class LiarsDiceSeats extends StatelessWidget {
  const LiarsDiceSeats({
    super.key,
    required this.match,
    required this.view,
    required this.viewerId,
    required this.clock,
  });

  final ChatMatch match;
  final LiarsDiceView view;
  final String viewerId;
  final MatchController clock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = match;
    final v = view;
    final active = m.status == MatchStatus.active;
    return PartySeatStrip(
      match: m,
      viewerId: viewerId,
      clock: clock,
      deadline: active ? v.deadline : null,
      total: partyPhaseLength('liarsdice', v.phase),
      seats: [
        for (var i = 0; i < m.seats.length; i++)
          PartySeat(
            seat: i,
            badge: DiceCup(count: i < v.counts.length ? v.counts[i] : 0),
            note: v.isOut(i) ? l10n.chatGameLdOut : null,
            dim: v.isOut(i) || (i < v.left.length && v.left[i]),
            timed: active && !v.over && v.turn == i,
          ),
      ],
    );
  }
}

/// Beside the dice on the desktop stage: the table, and this round's bids in
/// the order they were made, newest at the top, so a raise can be read
/// against the whole climb rather than only the last step.
class LiarsDiceStagePanel extends StatelessWidget {
  const LiarsDiceStagePanel({
    super.key,
    required this.match,
    required this.controller,
    required this.viewerId,
  });

  final ChatMatch match;
  final MatchController controller;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final v = partyViewOf(match);
    if (v is! LiarsDiceView) return const SizedBox.shrink();
    final palette = SeatPalette(theme, gameId: match.game);
    final bids = v.bids.reversed.toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PartyPanel(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
          child: LiarsDiceSeats(
            match: match,
            view: v,
            viewerId: viewerId,
            clock: controller,
          ),
        ),
        const SizedBox(height: 18),
        PartyStageSection(
          title: l10n.chatGameLdRoundDice(v.totalDice, v.round),
          child: PartyPanel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: bids.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: PartyCaption(l10n.chatGameLdNoBid),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < bids.length; i++)
                        Opacity(
                          opacity: i == 0 ? 1 : 0.62,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: palette.fill(bids[i].seat),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    seatName(l10n, match, bids[i].seat, viewerId),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: groupedTitleStyle(theme).copyWith(
                                      fontWeight: i == 0
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${bids[i].qty} ×',
                                  style: groupedTitleStyle(theme).copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DieFace(face: bids[i].face, size: 26),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
