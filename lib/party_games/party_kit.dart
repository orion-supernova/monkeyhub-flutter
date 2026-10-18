/// What the three party tables share: the phase clock (a ring that drains and
/// a number that counts), the row of faces along the top, and the card every
/// panel sits on.
///
/// The clock reads the SERVER's deadline through [MatchController.remaining],
/// which corrects for a phone whose clock is off. The ring is one
/// [AnimationController] per ring, run once per phase from what is left down
/// to zero, so it repaints on its own layer every frame without rebuilding a
/// single widget; the number beside it is its own one-second timer. Under
/// MotionScope calm the ring steps once a second instead of draining.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_games/match_face.dart';
import '../data/matches_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/seat_palette.dart';
import '../widgets/ios_kit.dart';

/// How long each timed phase lasts, from the server's constants
/// (`TURN_MS`, `REVEAL_MS`, `CLUE_MS`, `VOTE_MS`, `GUESS_MS`, `RACE_MS`). The
/// ring's full circle; a deadline further out than this (a clock that ran
/// ahead) is drawn full, never more.
Duration partyPhaseLength(String game, String phase) => switch ((game, phase)) {
  ('liarsdice', _) => const Duration(seconds: 45),
  ('imposter', 'reveal') => const Duration(seconds: 12),
  ('imposter', 'guess') => const Duration(seconds: 30),
  ('imposter', _) => const Duration(seconds: 40),
  ('race', _) => const Duration(minutes: 10),
  _ => const Duration(seconds: 45),
};

/// Under this much time left, the ring and the number turn red.
const _hurry = Duration(seconds: 10);

/// `0:42` past a minute, `42` under one: a ten-minute race reads as a clock,
/// a 40 second vote as a count.
String formatPartyClock(Duration left) {
  final s = left.inSeconds + (left.inMilliseconds % 1000 > 0 ? 1 : 0);
  if (s < 60) return '$s';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// A ring around [child] that drains as the phase's clock runs out.
class PhaseRing extends StatefulWidget {
  const PhaseRing({
    super.key,
    required this.clock,
    required this.deadline,
    required this.total,
    required this.color,
    required this.child,
    this.stroke = 3,
    this.gap = 3,
  });

  final MatchController clock;

  /// Server ms. Null draws no ring.
  final int? deadline;
  final Duration total;
  final Color color;
  final Widget child;
  final double stroke;

  /// Space between [child] and the ring.
  final double gap;

  @override
  State<PhaseRing> createState() => _PhaseRingState();
}

class _PhaseRingState extends State<PhaseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _left = AnimationController(vsync: this);
  Timer? _step;
  bool _calm = false;
  bool _paused = false;

  bool get _isPaused => widget.clock.serverMatch?.status == MatchStatus.paused;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MotionScope.of(context).calm;
    if (calm != _calm) {
      _calm = calm;
      _sync();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  @override
  void didUpdateWidget(PhaseRing old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline ||
        old.total != widget.total ||
        _isPaused != _paused) {
      _sync();
    }
  }

  /// Restarts the drain from wherever the server's clock says it is.
  void _sync() {
    _step?.cancel();
    _step = null;
    _left.stop();
    final deadline = widget.deadline;
    if (deadline == null) {
      _left.value = 0;
      _paused = _isPaused;
      return;
    }
    final total = widget.total.inMilliseconds;
    final left = widget.clock.remaining(deadline);
    _left.value = (left.inMilliseconds / total).clamp(0.0, 1.0);
    _paused = _isPaused;
    if (_paused || left == Duration.zero) return;
    if (_calm) {
      _step = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = widget.clock.remaining(deadline).inMilliseconds;
        _left.value = (now / total).clamp(0.0, 1.0);
        if (now <= 0) _step?.cancel();
      });
    } else {
      _left.animateTo(0, duration: left, curve: Curves.linear);
    }
  }

  @override
  void dispose() {
    _step?.cancel();
    _left.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final inset = widget.stroke + widget.gap;
    return CustomPaint(
      foregroundPainter: widget.deadline == null
          ? null
          : _RingPainter(
              left: _left,
              color: widget.color,
              hurry: theme.danger,
              track: theme.ink.withValues(alpha: theme.isLight ? 0.08 : 0.14),
              stroke: widget.stroke,
              hurryBelow: _hurry.inMilliseconds / widget.total.inMilliseconds,
            ),
      child: Padding(padding: EdgeInsets.all(inset), child: widget.child),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.left,
    required this.color,
    required this.hurry,
    required this.track,
    required this.stroke,
    required this.hurryBelow,
  }) : super(repaint: left);

  final Animation<double> left;
  final Color color;
  final Color hurry;
  final Color track;
  final double stroke;
  final double hurryBelow;

  // One paint each, reused every frame: the ring repaints at the display's
  // rate while a turn runs.
  final Paint _track = Paint()..style = PaintingStyle.stroke;
  final Paint _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - stroke / 2;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    _track
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(c, r, _track);
    final v = left.value;
    if (v <= 0) return;
    _arc
      ..strokeWidth = stroke
      ..color = v <= hurryBelow ? hurry : color;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * v, false, _arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.left != left ||
      old.color != color ||
      old.hurry != hurry ||
      old.track != track ||
      old.stroke != stroke ||
      old.hurryBelow != hurryBelow;
}

/// The phase's time left as a number, ticking once a second on its own so
/// nothing around it rebuilds.
class PhaseCountdown extends StatefulWidget {
  const PhaseCountdown({
    super.key,
    required this.clock,
    required this.deadline,
    this.style,
  });

  final MatchController clock;
  final int? deadline;
  final TextStyle? style;

  @override
  State<PhaseCountdown> createState() => _PhaseCountdownState();
}

class _PhaseCountdownState extends State<PhaseCountdown> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(PhaseCountdown old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) _arm();
  }

  void _arm() {
    _tick?.cancel();
    _tick = null;
    if (widget.deadline == null) return;
    // Half a second, so the number never sits a whole second behind the
    // ring it is drawn beside.
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {});
      if (widget.clock.remaining(widget.deadline) == Duration.zero) {
        _tick?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final deadline = widget.deadline;
    if (deadline == null) return const SizedBox.shrink();
    final left = widget.clock.remaining(deadline);
    final base = widget.style ?? groupedTitleStyle(theme);
    return Text(
      formatPartyClock(left),
      style: base.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: left < _hurry ? theme.danger : base.color,
      ),
    );
  }
}

/// A small pill with a stopwatch glyph and [PhaseCountdown]: the phase clock
/// where there is no face to put a ring around.
class PhaseClockPill extends StatelessWidget {
  const PhaseClockPill({
    super.key,
    required this.clock,
    required this.deadline,
  });

  final MatchController clock;
  final int? deadline;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (deadline == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 11, 4),
      decoration: BoxDecoration(
        color: theme.ink.withValues(alpha: theme.isLight ? 0.06 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.timer, size: 15, color: theme.inkSoft),
          const SizedBox(width: 5),
          PhaseCountdown(
            clock: clock,
            deadline: deadline,
            style: groupedMetaStyle(theme).copyWith(
              color: theme.inkSoft,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// The surface every party panel sits on: the grouped fill and radius the
/// rest of the game screen uses.
class PartyPanel extends StatelessWidget {
  const PartyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.tint,
  });

  final Widget child;
  final EdgeInsets padding;

  /// A colour washed over the fill: the active player's seat colour, a red
  /// for the imposter's card.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final fill = groupedFill(theme);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint == null ? fill : Color.alphaBlend(tint!, fill),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: child,
    );
  }
}

/// One player along the top of a party table.
class PartySeat {
  const PartySeat({
    required this.seat,
    this.note,
    this.noteColor,
    this.badge,
    this.dim = false,
    this.selected = false,
    this.timed = false,
    this.verbatim = false,
    this.keyLabel,
  });

  final int seat;

  /// The key that picks this seat on a keyboard ("1", "2", …), drawn as a
  /// small keycap on the face's upper leading corner. Desktop only.
  final String? keyLabel;

  /// [note] is the player's own words (an Imposter clue): shown as typed,
  /// not sentence-cased like the app's labels.
  final bool verbatim;

  /// Under the name: "Out", "Voted", 4 votes.
  final String? note;
  final Color? noteColor;

  /// On the face's lower trailing corner: a dice cup, a tick.
  final Widget? badge;

  /// Out of the game, or gone.
  final bool dim;

  /// The viewer's pick (a vote): an accent ring instead of the seat colour.
  final bool selected;

  /// Whose clock is running: the phase ring goes around this one.
  final bool timed;
}

/// The table's players as a row of faces, each in its seat colour, the one
/// whose clock runs wearing the draining ring. Wraps to a second row past
/// what fits; a tap on a face is [onTap]'s (Imposter's vote).
class PartySeatStrip extends StatelessWidget {
  const PartySeatStrip({
    super.key,
    required this.match,
    required this.viewerId,
    required this.seats,
    required this.clock,
    this.deadline,
    this.total = const Duration(seconds: 45),
    this.faceSize = 46,
    this.onTap,
  });

  final ChatMatch match;
  final String viewerId;
  final List<PartySeat> seats;
  final MatchController clock;
  final int? deadline;
  final Duration total;
  final double faceSize;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = SeatPalette(theme, gameId: match.game);
    final width = faceSize + 26;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 12,
      children: [
        for (final s in seats)
          SizedBox(
            width: width,
            child: _SeatToken(
              match: match,
              seat: s,
              name: s.seat < match.seats.length
                  ? (match.seats[s.seat].userId == viewerId
                        ? l10n.momentRailYouLabel
                        : match.seats[s.seat].name)
                  : '',
              color: palette.fill(s.seat),
              accent: theme.accent,
              clock: clock,
              deadline: s.timed ? deadline : null,
              total: total,
              faceSize: faceSize,
              onTap: onTap == null ? null : () => onTap!(s.seat),
            ),
          ),
      ],
    );
  }
}

class _SeatToken extends StatelessWidget {
  const _SeatToken({
    required this.match,
    required this.seat,
    required this.name,
    required this.color,
    required this.accent,
    required this.clock,
    required this.deadline,
    required this.total,
    required this.faceSize,
    this.onTap,
  });

  final ChatMatch match;
  final PartySeat seat;
  final String name;
  final Color color;
  final Color accent;
  final MatchController clock;
  final int? deadline;
  final Duration total;
  final double faceSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final s = seat.seat < match.seats.length ? match.seats[seat.seat] : null;
    final ring = seat.selected ? accent : color;
    Widget face = s == null
        ? SizedBox(width: faceSize, height: faceSize)
        : MatchFace(
            roomId: match.roomId,
            userId: s.userId,
            name: s.name,
            size: faceSize,
          );
    if (seat.dim) face = Opacity(opacity: 0.4, child: face);
    // The seat colour as a thin static ring; the clock's draining ring
    // replaces it on whoever is timed, so a face never wears two.
    final ringed = deadline != null
        ? PhaseRing(
            clock: clock,
            deadline: deadline,
            total: total,
            color: ring,
            stroke: 3,
            gap: 2.5,
            child: face,
          )
        : Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: seat.dim ? ring.withValues(alpha: 0.35) : ring,
                width: seat.selected ? 3 : 2,
              ),
            ),
            child: face,
          );
    final token = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ringed,
            if (seat.badge != null)
              PositionedDirectional(end: -4, bottom: -2, child: seat.badge!),
            if (seat.keyLabel != null)
              PositionedDirectional(
                start: -4,
                top: -4,
                child: KeyCap(seat.keyLabel!),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: groupedMetaStyle(theme).copyWith(
            color: seat.dim ? theme.inkMuted : theme.ink,
            fontWeight: seat.timed || seat.selected
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        if (seat.note != null)
          Text(
            seat.verbatim ? seat.note! : sentenceCaseOf(context, seat.note!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: groupedMetaStyle(theme).copyWith(
              fontSize: 12,
              color: seat.noteColor ?? theme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
    final tap = onTap;
    return Semantics(
      button: tap != null,
      selected: seat.selected,
      label: [name, if (seat.note != null) seat.note!].join(', '),
      child: ExcludeSemantics(
        child: tap == null
            ? token
            : SpringPress(onTap: tap, scale: PressSpec.scaleSmall, child: token),
      ),
    );
  }
}

/// A small round badge for a face's corner: a tick, a count.
class SeatBadge extends StatelessWidget {
  const SeatBadge({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: groupedFill(theme), width: 2),
      ),
      child: child,
    );
  }
}

/// A one-line caption in the meta style, centred: the hint under a panel.
class PartyCaption extends StatelessWidget {
  const PartyCaption(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text(
      sentenceCaseOf(context, text),
      textAlign: TextAlign.center,
      style: groupedMetaStyle(theme).copyWith(color: color ?? theme.inkMuted),
    );
  }
}

/// [AppTheme]-aware ink for text drawn on [fill].
Color inkOn(AppTheme theme, Color fill) =>
    fill.computeLuminance() > 0.45 ? const Color(0xFF1C1C1E) : Colors.white;

/// A key's name on a small rounded cap: the keyboard hint beside something
/// a key can pick.
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.ink.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: groupedMetaStyle(theme).copyWith(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: theme.inkSoft,
        ),
      ),
    );
  }
}

/// A party table's middle on the desktop stage: the same panels as on a
/// phone, in a column no wider than reads well, centred in the square the
/// stage gives it, and scrolling only if a phase ever runs taller than it.
class PartyStageBody extends StatelessWidget {
  const PartyStageBody({
    super.key,
    required this.child,
    this.maxWidth = 560,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// The panel beside a party table on the desktop stage: a heading and its
/// card, stacked, scrolling as one.
class PartyStageSection extends StatelessWidget {
  const PartyStageSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            sentenceCaseOf(context, title),
            style: groupedMetaStyle(theme).copyWith(
              color: theme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Whether [event] is a plain key press this table may take: a key down or
/// repeat with no ⌘/Ctrl/Alt held (those chords belong to the app).
bool plainKeyDown(KeyEvent event) {
  if (event is KeyUpEvent) return false;
  final k = HardwareKeyboard.instance;
  return !(k.isMetaPressed || k.isControlPressed || k.isAltPressed);
}
