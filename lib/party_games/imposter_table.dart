import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/convex_client.dart';
import '../backend/group_call_api.dart';
import '../calls/call_models.dart' show CallMediaKind;
import '../calls/group_call_banner.dart';
import '../calls/group_call_button.dart';
import '../calls/group_call_service.dart';
import '../chat_games/match_copy.dart';
import '../chat_games/match_face.dart';
import '../data/matches_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../games/game_canvas.dart' show digitOfKey;
import '../models/chat_match.dart';
import '../platform.dart' show isPhysicalKeyboardPlatform;
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/seat_palette.dart';
import '../widgets/ios_kit.dart';
import '../widgets/labeled_field.dart' show SheetTextField;
import 'party_kit.dart';
import 'party_views.dart';

/// The most characters a clue may have, and words: `MAX_CLUE` and
/// `MAX_CLUE_WORDS` in imposter.ts.
const kMaxClueChars = 24;
const kMaxClueWords = 4;
const kMaxGuessChars = 48;

/// Why a typed clue cannot be sent yet, or null when it can. The server
/// checks the same (`cleanClue`), plus links, and says `BAD_CLUE`; checking
/// here first means the button is simply off rather than a round trip away
/// from a refusal.
enum ClueProblem { empty, tooLong, tooManyWords }

ClueProblem? clueProblem(String raw) {
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return ClueProblem.empty;
  if (text.characters.length > kMaxClueChars) return ClueProblem.tooLong;
  if (text.split(' ').length > kMaxClueWords) return ClueProblem.tooManyWords;
  return null;
}

/// IMPOSTER at the table, one phase at a time: your card, the clues as they
/// land, the vote, the imposter's last guess, and the reveal.
///
/// Your card is face down and shows only while it is held, so a phone left on
/// the table (or a friend looking over a shoulder) never gives the word away.
/// It stays at the top through every phase in a smaller form; the word is
/// what every clue is about, and nobody should have to remember it.
class ImposterTable extends StatefulWidget {
  const ImposterTable({
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
  final bool enabled;

  /// The desktop stage's middle: the clues move to [ImposterStagePanel]
  /// beside it, and the vote takes number keys.
  final bool stage;

  @override
  State<ImposterTable> createState() => _ImposterTableState();
}

class _ImposterTableState extends State<ImposterTable> {
  final TextEditingController _text = TextEditingController();
  String? _secretRaw;
  ImposterSecret? _secret;
  String? _phaseKey;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  ImposterView? get _view {
    final v = partyViewOf(widget.match);
    return v is ImposterView ? v : null;
  }

  ImposterSecret? get _mine {
    final raw = widget.controller.secret;
    if (raw != _secretRaw) {
      _secretRaw = raw;
      try {
        _secret = raw == null ? null : ImposterSecret.fromJson(jsonDecode(raw));
      } catch (_) {
        _secret = null;
      }
    }
    return _secret;
  }

  /// A new phase (or a new clue turn) clears whatever was typed for the last.
  void _notePhase(ImposterView v) {
    final key = '${v.phase}:${v.turn}';
    if (key == _phaseKey) return;
    _phaseKey = key;
    if (_text.text.isNotEmpty) _text.clear();
  }

  Future<void> _send(String action) async {
    HapticFeedback.selectionClick();
    final ok = await widget.controller.act(action);
    if (ok && mounted) _text.clear();
  }

  /// Desktop keys in the vote: the number on a face votes for it, 0 skips.
  /// A focused text field never gets here: it keeps its own digits.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!plainKeyDown(event)) return KeyEventResult.ignored;
    final v = _view;
    final m = widget.match;
    final mySeat = m.seatOf(widget.viewerId);
    if (v == null ||
        v.phase != 'vote' ||
        !widget.enabled ||
        mySeat < 0 ||
        m.status != MatchStatus.active) {
      return KeyEventResult.ignored;
    }
    final digit = digitOfKey(event.logicalKey);
    if (digit == null || event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      return KeyEventResult.ignored;
    }
    final mine = _pendingVote ?? _mine?.myVote;
    if (digit == 0) {
      if (mine != -1) _send('vote:skip');
      return KeyEventResult.handled;
    }
    final targets = imposterVoteKeys(v.living, mySeat);
    final target = targets[digit];
    if (target != null && target != mine) _send('vote:$target');
    return KeyEventResult.handled;
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
    final v = _view;
    if (v == null) return const SizedBox.shrink();
    _notePhase(v);
    final m = widget.match;
    final me = widget.viewerId;
    final mySeat = m.seatOf(me);
    final secret = _mine;
    final children = <Widget>[];

    if (v.phase == 'over') {
      children.add(_OverPanel(match: m, view: v, viewerId: me));
      if (!widget.stage) {
        children.add(const SizedBox(height: 12));
        children.add(_ClueList(match: m, view: v, viewerId: me, clock: widget.controller));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    if (mySeat >= 0) {
      children.add(_RoleCard(
        secret: secret,
        compact: v.phase != 'reveal',
      ));
      children.add(const SizedBox(height: 12));
    }

    switch (v.phase) {
      case 'reveal':
        children.add(_RevealFooter(
          match: m,
          view: v,
          viewerId: me,
          controller: widget.controller,
          enabled: widget.enabled,
        ));
      case 'clues':
        if (v.voice) {
          children.add(_VoiceBar(match: m, viewerId: me));
          children.add(const SizedBox(height: 12));
        }
        if (!widget.stage) {
          children.add(_ClueList(match: m, view: v, viewerId: me, clock: widget.controller));
        } else if (!(m.isTurnOf(me) && v.turn == mySeat)) {
          children.add(_ClueWait(match: m, view: v, viewerId: me, clock: widget.controller));
        }
        if (m.isTurnOf(me) && v.turn == mySeat) {
          if (!widget.stage) children.add(const SizedBox(height: 12));
          children.add(v.voice
              ? _VoiceTurn(
                  busy: widget.controller.pendingAction != null,
                  onDone: widget.enabled ? () => _send('done') : null,
                )
              : _ClueEntry(
                  controller: _text,
                  busy: widget.controller.pendingAction != null,
                  enabled: widget.enabled,
                  onSend: (text) => _send('clue:$text'),
                ));
        }
      case 'vote':
        children.add(_VotePanel(
          match: m,
          view: v,
          viewerId: me,
          controller: widget.controller,
          myVote: _pendingVote ?? secret?.myVote,
          enabled: widget.enabled,
          keys: widget.stage && isPhysicalKeyboardPlatform,
          onVote: (target) => _send(target < 0 ? 'vote:skip' : 'vote:$target'),
        ));
      case 'guess':
        final guessing = v.accused == mySeat && mySeat >= 0;
        children.add(guessing
            ? _GuessEntry(
                controller: _text,
                busy: widget.controller.pendingAction != null,
                enabled: widget.enabled,
                clock: widget.controller,
                deadline: v.deadline,
                onGuess: (text) => _send('guess:$text'),
              )
            : _GuessWait(match: m, view: v, viewerId: me, clock: widget.controller));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  /// A vote in flight shows as cast at once; the secret's echo confirms it.
  int? get _pendingVote {
    final a = widget.controller.pendingAction;
    if (a == null || !a.startsWith('vote:')) return null;
    final target = a.substring(5);
    return target == 'skip' ? -1 : int.tryParse(target);
  }
}

// ── The card ────────────────────────────────────────────────────────────────

/// Your card, face down until held. Holding fills a ring around the eye with
/// a light tick at each quarter, then turns the card; letting go turns it
/// back. The hold is deliberate on purpose: a brush of the thumb while
/// scrolling must not flash the word to the room.
class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.secret, required this.compact});

  final ImposterSecret? secret;

  /// After the reveal phase: one row tall, the word inline while held.
  final bool compact;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addListener(_onHold);
  bool _open = false;
  int _ticks = 0;

  void _onHold() {
    final quarter = (_hold.value * 4).floor();
    if (_hold.status == AnimationStatus.forward && quarter > _ticks && quarter < 4) {
      _ticks = quarter;
      HapticFeedback.selectionClick();
    }
    // Never on the way back down: letting go starts the reverse at 1.0, and
    // that first tick must not turn the card over again.
    if (_hold.value >= 1 && !_open && _hold.status != AnimationStatus.reverse) {
      HapticFeedback.mediumImpact();
      setState(() => _open = true);
    }
  }

  void _down() {
    if (widget.secret == null) return;
    _ticks = 0;
    if (MotionScope.of(context).calm) {
      _hold.value = 1;
      return;
    }
    _hold.forward(from: _hold.value);
  }

  void _up() {
    if (_open) setState(() => _open = false);
    _hold.reverse();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final s = widget.secret;
    final imposter = s?.imposter ?? false;
    final category = s == null ? '' : localName(s.categoryNames, locale);
    final word = s == null ? '' : localName(s.names, locale);
    final tint = _open
        ? (imposter ? theme.danger : theme.accent).withValues(alpha: 0.14)
        : null;
    final Widget face;
    if (!_open) {
      face = Row(
        mainAxisAlignment: widget.compact
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: AnimatedBuilder(
              animation: _hold,
              builder: (context, child) => CustomPaint(
                painter: _HoldRing(
                  value: _hold.value,
                  color: theme.accent,
                  track: theme.ink.withValues(alpha: 0.12),
                ),
                child: child,
              ),
              child: Icon(CupertinoIcons.eye_fill, size: 17, color: theme.inkSoft),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              sentenceCaseOf(context, l10n.chatGameImpHoldToSee),
              style: groupedTitleStyle(theme).copyWith(
                fontWeight: FontWeight.w600,
                color: theme.inkSoft,
              ),
            ),
          ),
        ],
      );
    } else if (widget.compact) {
      face = Row(
        children: [
          Icon(
            imposter ? CupertinoIcons.person_crop_circle_badge_xmark : CupertinoIcons.eye_fill,
            size: 22,
            color: imposter ? theme.danger : theme.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              imposter ? l10n.chatGameImpYouAre : word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: groupedTitleStyle(theme).copyWith(
                fontWeight: FontWeight.w700,
                color: imposter ? theme.danger : theme.ink,
              ),
            ),
          ),
          Text(
            category,
            style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
          ),
        ],
      );
    } else {
      face = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            sentenceCaseOf(
              context,
              imposter ? l10n.chatGameImpYouAre : l10n.chatGameImpYourWord,
            ),
            textAlign: TextAlign.center,
            style: imposter
                ? theme.displaySmall.copyWith(
                    color: theme.danger,
                    fontWeight: FontWeight.w800,
                  )
                : groupedMetaStyle(theme).copyWith(
                    color: theme.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
          ),
          if (!imposter) ...[
            const SizedBox(height: 6),
            Text(
              word,
              textAlign: TextAlign.center,
              style: theme.displayLarge.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.chatGameImpCategory(category),
            textAlign: TextAlign.center,
            style: groupedTitleStyle(theme).copyWith(color: theme.inkSoft),
          ),
          const SizedBox(height: 10),
          Text(
            sentenceCaseOf(
              context,
              imposter ? l10n.chatGameImpBlendIn : l10n.chatGameImpKeepSecret,
            ),
            textAlign: TextAlign.center,
            style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      label: l10n.chatGameImpHoldToSee,
      child: Listener(
        key: const ValueKey('imp_card'),
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: AnimatedContainer(
          duration: MotionScope.of(context).d(theme.motionFast),
          height: widget.compact ? 64 : 212,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint == null
                ? groupedFill(theme)
                : Color.alphaBlend(tint, groupedFill(theme)),
            borderRadius: BorderRadius.circular(groupedRadius(theme)),
            border: Border.all(
              color: _open
                  ? (imposter ? theme.danger : theme.accent).withValues(alpha: 0.5)
                  : theme.ink.withValues(alpha: 0.06),
              width: 1.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: MotionScope.of(context).d(const Duration(milliseconds: 160)),
            child: KeyedSubtree(key: ValueKey(_open), child: face),
          ),
        ),
      ),
    );
  }
}

class _HoldRing extends CustomPainter {
  _HoldRing({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = track;
    canvas.drawCircle(c, r, p);
    if (value <= 0) return;
    p
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5707963,
      6.2831853 * value,
      false,
      p,
    );
  }

  @override
  bool shouldRepaint(_HoldRing old) =>
      old.value != value || old.color != color || old.track != track;
}

// ── Reveal ──────────────────────────────────────────────────────────────────

class _RevealFooter extends StatelessWidget {
  const _RevealFooter({
    required this.match,
    required this.view,
    required this.viewerId,
    required this.controller,
    required this.enabled,
  });

  final ChatMatch match;
  final ImposterView view;
  final String viewerId;
  final MatchController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mySeat = match.seatOf(viewerId);
    final living = view.living;
    final looked = living.where((i) => i < view.seen.length && view.seen[i]).length;
    final seen = mySeat >= 0 && mySeat < view.seen.length && view.seen[mySeat];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PartySeatStrip(
          match: match,
          viewerId: viewerId,
          clock: controller,
          seats: [
            for (final i in living)
              PartySeat(
                seat: i,
                badge: i < view.seen.length && view.seen[i]
                    ? const _Tick()
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PartyCaption(l10n.chatGameImpLooked(looked, living.length)),
            const SizedBox(width: 10),
            PhaseClockPill(clock: controller, deadline: view.deadline),
          ],
        ),
        if (mySeat >= 0) ...[
          const SizedBox(height: 14),
          SheetActionButton(
            key: const ValueKey('imp_seen'),
            label: sentenceCaseOf(context, l10n.chatGameImpGotIt),
            icon: seen ? CupertinoIcons.checkmark : null,
            tonal: seen,
            busy: controller.pendingAction == 'seen',
            onTap: seen || !enabled ? null : () => controller.act('seen'),
          ),
        ],
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SeatBadge(
      color: theme.success,
      child: const Icon(CupertinoIcons.checkmark, size: 11, color: Colors.white),
    );
  }
}

// ── Clues ───────────────────────────────────────────────────────────────────

/// Everyone in clue order: the clues given so far, the one being given (with
/// its clock), and who is still to go.
class _ClueList extends StatelessWidget {
  const _ClueList({
    required this.match,
    required this.view,
    required this.viewerId,
    required this.clock,
  });

  final ChatMatch match;
  final ImposterView view;
  final String viewerId;
  final MatchController clock;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = SeatPalette(theme, gameId: match.game);
    final byseat = {for (final c in view.clues) c.seat: c};
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final rows = <Widget>[];
    for (final seat in view.order) {
      if (seat >= match.seats.length) continue;
      final gone = seat < view.left.length && view.left[seat];
      final clue = byseat[seat];
      if (gone && clue == null) continue;
      final now = view.phase == 'clues' && view.turn == seat;
      final s = match.seats[seat];
      Widget face = MatchFace(roomId: match.roomId, userId: s.userId, name: s.name, size: 34);
      face = now
          ? PhaseRing(
              clock: clock,
              deadline: view.deadline,
              total: partyPhaseLength('imposter', 'clues'),
              color: palette.fill(seat),
              stroke: 2.5,
              gap: 2,
              child: face,
            )
          : Padding(
              padding: const EdgeInsets.all(4.5),
              child: Opacity(opacity: clue == null ? 0.5 : 1, child: face),
            );
      final String text;
      final bool soft;
      if (clue != null) {
        if (clue.passed) {
          text = l10n.chatGameImpPassed;
          soft = true;
        } else if (view.voice || clue.text.isEmpty) {
          text = l10n.chatGameImpSpoke;
          soft = true;
        } else {
          text = clue.text;
          soft = false;
        }
      } else {
        text = now ? '…' : '';
        soft = true;
      }
      if (rows.isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 58),
          child: SizedBox(
            height: hairline,
            child: ColoredBox(color: theme.divider),
          ),
        ));
      }
      rows.add(AnimatedContainer(
        duration: MotionScope.of(context).d(theme.motionFast),
        color: now ? palette.wash(seat) : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        child: Row(
          children: [
            face,
            const SizedBox(width: 10),
            SizedBox(
              width: 84,
              child: Text(
                seatName(l10n, match, seat, viewerId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: groupedMetaStyle(theme).copyWith(
                  color: theme.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: MotionScope.of(context).d(theme.motionMed),
                // Start-aligned: the default centres the incoming clue.
                layoutBuilder: (current, previous) => Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: Text(
                  soft && text.isNotEmpty ? sentenceCaseOf(context, text) : text,
                  key: ValueKey('$seat:$text'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: soft
                      ? groupedTitleStyle(theme).copyWith(
                          color: theme.inkMuted,
                          fontStyle: FontStyle.italic,
                        )
                      : groupedTitleStyle(theme).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                ),
              ),
            ),
          ],
        ),
      ));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
      child: ColoredBox(
        color: groupedFill(theme),
        child: Column(children: rows),
      ),
    );
  }
}

class _ClueEntry extends StatelessWidget {
  const _ClueEntry({
    required this.controller,
    required this.busy,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final problem = clueProblem(controller.text);
    final text = controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final can = enabled && !busy && problem == null;
    final error = problem == ClueProblem.tooManyWords
        ? l10n.chatGameImpTooManyWords
        : null;
    final left = kMaxClueChars - controller.text.characters.length;
    return PartyPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No title: the line under the screen's title already says it is
          // your turn, and the field is the only thing here to do.
          Row(
            children: [
              Expanded(
                child: SheetTextField(
                  key: const ValueKey('imp_clue_field'),
                  controller: controller,
                  hint: l10n.chatGameImpClueField,
                  maxLength: kMaxClueChars,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.none,
                  enabled: enabled,
                  onSubmitted: (_) => can ? onSend(text) : null,
                ),
              ),
              const SizedBox(width: 10),
              SheetActionButton(
                key: const ValueKey('imp_clue_send'),
                label: sentenceCaseOf(context, l10n.chatGameImpSend),
                expand: false,
                busy: busy,
                onTap: can ? () => onSend(text) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  sentenceCaseOf(
                    context,
                    error ??
                        '${l10n.chatGameImpClueHint} · '
                            '${sentenceCaseOf(context, l10n.partyImposterClueRule)}',
                  ),
                  style: groupedMetaStyle(theme).copyWith(
                    color: error != null ? theme.danger : theme.inkMuted,
                  ),
                ),
              ),
              Text(
                '$left',
                style: groupedMetaStyle(theme).copyWith(
                  color: left <= 4 ? theme.danger : theme.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Voice mode: the room's call, so everyone can hear the clues. The banner is
/// the room's own (who is in, a Join pill); with no call going yet, a button
/// starts one, through the same sheet the room header's call button opens.
class _VoiceBar extends StatelessWidget {
  const _VoiceBar({required this.match, required this.viewerId});

  final ChatMatch match;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final service = GroupCallService.maybeInstance;
    if (service == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final here = service.inCall && service.roomId == match.roomId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GroupCallBanner(
              api: GroupCallApi(ConvexBackend.instance),
              service: service,
              roomId: match.roomId,
              userId: viewerId,
            ),
            if (here)
              PartyCaption(l10n.chatGameImpOnCall)
            else if (!service.inCall)
              SheetActionButton(
                label: sentenceCaseOf(context, l10n.chatGameImpJoinCall),
                icon: CupertinoIcons.phone_fill,
                tonal: true,
                onTap: () => GroupCallButton(
                  roomId: match.roomId,
                  kind: CallMediaKind.audio,
                ).activate(context),
              ),
          ],
        );
      },
    );
  }
}

class _VoiceTurn extends StatelessWidget {
  const _VoiceTurn({required this.busy, this.onDone});

  final bool busy;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return PartyPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sentenceCaseOf(context, l10n.chatGameImpYourClue),
            textAlign: TextAlign.center,
            style: groupedTitleStyle(theme).copyWith(
              fontWeight: FontWeight.w700,
              color: theme.accent,
            ),
          ),
          const SizedBox(height: 4),
          PartyCaption(l10n.chatGameImpVoiceHint),
          const SizedBox(height: 12),
          SheetActionButton(
            key: const ValueKey('imp_voice_done'),
            label: sentenceCaseOf(context, l10n.chatGameImpDone),
            busy: busy,
            onTap: busy ? null : onDone,
          ),
        ],
      ),
    );
  }
}

// ── Vote ────────────────────────────────────────────────────────────────────

class _VotePanel extends StatelessWidget {
  const _VotePanel({
    required this.match,
    required this.view,
    required this.viewerId,
    required this.controller,
    required this.myVote,
    required this.enabled,
    required this.onVote,
    this.keys = false,
  });

  final ChatMatch match;
  final ImposterView view;
  final String viewerId;
  final MatchController controller;
  final int? myVote;
  final bool enabled;
  final ValueChanged<int> onVote;

  /// Desktop: a number on every face that can be voted for, and the hint.
  final bool keys;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mySeat = match.seatOf(viewerId);
    final playing = mySeat >= 0 && match.status == MatchStatus.active;
    final living = view.living;
    final voted = living.where((i) => i < view.voted.length && view.voted[i]).length;
    final clues = {for (final c in view.clues) c.seat: c};
    final keyOf = {
      for (final e in imposterVoteKeys(living, mySeat).entries) e.value: e.key,
    };
    String? clueOf(int seat) {
      final c = clues[seat];
      if (c == null || c.passed || c.text.isEmpty || view.voice) return null;
      return c.text;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PartyPanel(
          child: Column(
            children: [
              Text(
                sentenceCaseOf(context, l10n.chatGameImpVoteTitle),
                textAlign: TextAlign.center,
                style: theme.displaySmall.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              if (playing) PartyCaption(l10n.chatGameImpVoteHint),
              const SizedBox(height: 16),
              PartySeatStrip(
                match: match,
                viewerId: viewerId,
                clock: controller,
                // Four across on a phone, before a second row.
                faceSize: 50,
                onTap: playing && enabled
                    ? (seat) {
                        if (seat == mySeat || seat == myVote) return;
                        onVote(seat);
                      }
                    : null,
                seats: [
                  for (final i in living)
                    PartySeat(
                      seat: i,
                      selected: myVote == i,
                      note: myVote == i ? l10n.chatGameImpYourVote : clueOf(i),
                      noteColor: myVote == i ? theme.accent : theme.inkSoft,
                      verbatim: myVote != i,
                      badge: i < view.voted.length && view.voted[i]
                          ? const _Tick()
                          : null,
                      dim: i == mySeat,
                      keyLabel: keys && playing && keyOf[i] != null
                          ? '${keyOf[i]}'
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PartyCaption(l10n.chatGameImpVoted(voted, living.length)),
                  const SizedBox(width: 10),
                  PhaseClockPill(clock: controller, deadline: view.deadline),
                ],
              ),
            ],
          ),
        ),
        if (playing) ...[
          const SizedBox(height: 12),
          SheetActionButton(
            key: const ValueKey('imp_skip'),
            label: sentenceCaseOf(context, l10n.chatGameImpSkip),
            icon: myVote == -1 ? CupertinoIcons.checkmark : null,
            tonal: true,
            onTap: enabled && myVote != -1 ? () => onVote(-1) : null,
          ),
          if (keys) ...[
            const SizedBox(height: 10),
            PartyCaption(l10n.partyImposterVoteKeys),
          ],
        ],
      ],
    );
  }
}

// ── Guess ───────────────────────────────────────────────────────────────────

class _GuessEntry extends StatelessWidget {
  const _GuessEntry({
    required this.controller,
    required this.busy,
    required this.enabled,
    required this.clock,
    required this.deadline,
    required this.onGuess,
  });

  final TextEditingController controller;
  final bool busy;
  final bool enabled;
  final MatchController clock;
  final int? deadline;
  final ValueChanged<String> onGuess;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final text = controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final can = enabled && !busy && text.isNotEmpty;
    return PartyPanel(
      tint: theme.danger.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sentenceCaseOf(context, l10n.chatGameImpGuessHint),
                  style: groupedTitleStyle(theme).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              PhaseClockPill(clock: clock, deadline: deadline),
            ],
          ),
          const SizedBox(height: 12),
          SheetTextField(
            key: const ValueKey('imp_guess_field'),
            controller: controller,
            hint: l10n.chatGameImpGuessField,
            maxLength: kMaxGuessChars,
            autofocus: true,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.none,
            enabled: enabled,
            onSubmitted: (_) => can ? onGuess(text) : null,
          ),
          const SizedBox(height: 12),
          SheetActionButton(
            key: const ValueKey('imp_guess_send'),
            label: sentenceCaseOf(context, l10n.chatGameImpGuess),
            busy: busy,
            onTap: can ? () => onGuess(text) : null,
          ),
        ],
      ),
    );
  }
}

class _GuessWait extends StatelessWidget {
  const _GuessWait({
    required this.match,
    required this.view,
    required this.viewerId,
    required this.clock,
  });

  final ChatMatch match;
  final ImposterView view;
  final String viewerId;
  final MatchController clock;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final accused = view.accused;
    final s = accused != null && accused < match.seats.length
        ? match.seats[accused]
        : null;
    return PartyPanel(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      child: Column(
        children: [
          if (s != null)
            PhaseRing(
              clock: clock,
              deadline: view.deadline,
              total: partyPhaseLength('imposter', 'guess'),
              color: theme.danger,
              stroke: 3.5,
              child: MatchFace(
                roomId: match.roomId,
                userId: s.userId,
                name: s.name,
                size: 72,
              ),
            ),
          const SizedBox(height: 12),
          if (accused != null)
            Text(
              seatName(l10n, match, accused, viewerId),
              style: groupedTitleStyle(theme).copyWith(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 4),
          Text(
            sentenceCaseOf(context, l10n.chatGameImpGuessing),
            textAlign: TextAlign.center,
            style: theme.displaySmall,
          ),
          const SizedBox(height: 8),
          PhaseClockPill(clock: clock, deadline: view.deadline),
        ],
      ),
    );
  }
}

// ── Over ────────────────────────────────────────────────────────────────────

/// The reveal: who it was, the word, the guess if there was one, and how
/// everyone voted.
class _OverPanel extends StatelessWidget {
  const _OverPanel({
    required this.match,
    required this.view,
    required this.viewerId,
  });

  final ChatMatch match;
  final ImposterView view;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final imp = view.imposter;
    final s = imp != null && imp < match.seats.length ? match.seats[imp] : null;
    final word = view.word;
    final counts = view.voteCounts;
    final guess = view.guess;
    final votes = <int>[
      if (counts != null)
        for (var i = 0; i < counts.length && i < match.seats.length; i++)
          if (counts[i] > 0) i,
    ]..sort((a, b) => counts![b].compareTo(counts[a]));
    return PartyPanel(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.danger, width: 3),
                ),
                child: MatchFace(
                  roomId: match.roomId,
                  userId: s.userId,
                  name: s.name,
                  size: 72,
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (s != null)
            Text(
              sentenceCaseOf(
                context,
                s.userId == viewerId
                    ? l10n.chatGameImpYouWere
                    : l10n.chatGameImpWas(s.name),
              ),
              textAlign: TextAlign.center,
              style: theme.displaySmall.copyWith(fontWeight: FontWeight.w800),
            ),
          if (word != null) ...[
            const SizedBox(height: 18),
            Text(
              sentenceCaseOf(context, l10n.chatGameImpTheWord),
              textAlign: TextAlign.center,
              style: groupedMetaStyle(theme).copyWith(
                color: theme.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              localName(word.names, locale),
              textAlign: TextAlign.center,
              style: theme.displayLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.accent,
              ),
            ),
            Text(
              l10n.chatGameImpCategory(localName(word.categoryNames, locale)),
              textAlign: TextAlign.center,
              style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
            ),
          ],
          if (guess != null && guess.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  view.guessCorrect == true
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.xmark_circle_fill,
                  size: 18,
                  color: view.guessCorrect == true ? theme.success : theme.danger,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.chatGameImpTheyGuessed(guess),
                    style: groupedTitleStyle(theme),
                  ),
                ),
              ],
            ),
          ],
          if (votes.isNotEmpty || (view.skips ?? 0) > 0) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: theme.divider),
            const SizedBox(height: 10),
            for (final i in votes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    MatchFace(
                      roomId: match.roomId,
                      userId: match.seats[i].userId,
                      name: match.seats[i].name,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        seatName(l10n, match, i, viewerId),
                        style: groupedTitleStyle(theme).copyWith(
                          fontWeight: i == view.accused
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == imp ? theme.danger : theme.ink,
                        ),
                      ),
                    ),
                    Text(
                      l10n.chatGameImpVotes(counts![i]),
                      style: groupedMetaStyle(theme).copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            if ((view.skips ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: PartyCaption(l10n.chatGameImpSkipped(view.skips!)),
              ),
          ],
        ],
      ),
    );
  }
}

/// The number key for each seat that can be voted for, in the order the vote
/// shows the faces (everyone still in), skipping the voter: `{1: seat, …}`.
Map<int, int> imposterVoteKeys(List<int> living, int mySeat) {
  final out = <int, int>{};
  var k = 1;
  for (final seat in living) {
    if (seat == mySeat) continue;
    if (k > 9) break;
    out[k++] = seat;
  }
  return out;
}

/// On the desktop stage, while someone else gives their clue: who it is and
/// their clock, large, since the clues themselves are in the panel beside.
class _ClueWait extends StatelessWidget {
  const _ClueWait({
    required this.match,
    required this.view,
    required this.viewerId,
    required this.clock,
  });

  final ChatMatch match;
  final ImposterView view;
  final String viewerId;
  final MatchController clock;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final seat = view.turn;
    if (seat == null || seat >= match.seats.length) return const SizedBox.shrink();
    final s = match.seats[seat];
    final palette = SeatPalette(theme, gameId: match.game);
    return PartyPanel(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      child: Column(
        children: [
          PhaseRing(
            clock: clock,
            deadline: view.deadline,
            total: partyPhaseLength('imposter', 'clues'),
            color: palette.fill(seat),
            stroke: 3.5,
            child: MatchFace(
              roomId: match.roomId,
              userId: s.userId,
              name: s.name,
              size: 72,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sentenceCaseOf(
              context,
              l10n.chatGameTurnOf(seatName(l10n, match, seat, viewerId)),
            ),
            textAlign: TextAlign.center,
            style: groupedTitleStyle(theme).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          PhaseClockPill(clock: clock, deadline: view.deadline),
        ],
      ),
    );
  }
}

/// Beside the table on the desktop stage: every clue, in clue order, for the
/// whole game. The vote and the reveal both read against it, so it stays.
class ImposterStagePanel extends StatelessWidget {
  const ImposterStagePanel({
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
    final l10n = AppLocalizations.of(context);
    final v = partyViewOf(match);
    if (v is! ImposterView) return const SizedBox.shrink();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PartyStageSection(
          title: l10n.chatGameImpCardClues(v.clues.length, v.order.length),
          child: _ClueList(
            match: match,
            view: v,
            viewerId: viewerId,
            clock: controller,
          ),
        ),
      ],
    );
  }
}
