/// Liar's Dice's dice: real faces with pips, drawn, not glyphs.
///
/// A die is an ivory rounded square with a hairline edge and a soft bottom
/// lip (so it reads as a solid thing on both a white plate and a black one),
/// pips in near-black. A die that counts toward the bid on the table is
/// filled with the accent and pipped in its ink; one that does not is faded,
/// so the reveal reads as "these ones" at a glance.
///
/// A row of dice is ONE painter, not a widget per die: the reveal draws up to
/// thirty of them, and the pip layout is a const table, so a repaint
/// allocates nothing.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';

/// Pip centres on a unit die, per face.
const _pips = <List<Offset>>[
  [],
  [Offset(0.5, 0.5)],
  [Offset(0.27, 0.27), Offset(0.73, 0.73)],
  [Offset(0.27, 0.27), Offset(0.5, 0.5), Offset(0.73, 0.73)],
  [Offset(0.27, 0.27), Offset(0.73, 0.27), Offset(0.27, 0.73), Offset(0.73, 0.73)],
  [
    Offset(0.27, 0.27),
    Offset(0.73, 0.27),
    Offset(0.5, 0.5),
    Offset(0.27, 0.73),
    Offset(0.73, 0.73),
  ],
  [
    Offset(0.27, 0.25),
    Offset(0.73, 0.25),
    Offset(0.27, 0.5),
    Offset(0.73, 0.5),
    Offset(0.27, 0.75),
    Offset(0.73, 0.75),
  ],
];

/// How a die is drawn.
enum DieTone {
  /// Plain ivory.
  plain,

  /// Counts toward the bid: accent fill.
  hit,

  /// Does not count: faded.
  miss,

  /// Not known (a spectator's view, a seat's hidden hand): a blank face.
  hidden,
}

/// The colours a die is drawn in, from the theme. Built once per paint call
/// site and compared by value, so a painter only repaints on a real change.
@immutable
class DiceInk {
  DiceInk(AppTheme theme)
    : face = theme.isLight ? const Color(0xFFFFFFFF) : const Color(0xFFF4F1EA),
      edge = theme.isLight
          ? const Color(0x1F000000)
          : const Color(0x33000000),
      lip = theme.isLight ? const Color(0x24000000) : const Color(0x66000000),
      pip = const Color(0xFF1C1C1E),
      hit = theme.accent,
      hitPip = theme.accentInk,
      hidden = theme.ink.withValues(alpha: theme.isLight ? 0.08 : 0.14);

  final Color face;
  final Color edge;
  final Color lip;
  final Color pip;
  final Color hit;
  final Color hitPip;
  final Color hidden;

  @override
  bool operator ==(Object other) =>
      other is DiceInk &&
      other.face == face &&
      other.edge == edge &&
      other.lip == lip &&
      other.pip == pip &&
      other.hit == hit &&
      other.hitPip == hitPip &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(face, edge, lip, pip, hit, hitPip, hidden);
}

/// Paints one die of side [side] with its top-left at [at].
void paintDie(
  Canvas canvas,
  Offset at,
  double side,
  int face,
  DieTone tone,
  DiceInk ink,
  Paint scratch,
) {
  final r = Radius.circular(side * 0.24);
  final body = RRect.fromRectAndRadius(at & Size.square(side), r);
  if (tone == DieTone.hidden) {
    scratch
      ..style = PaintingStyle.fill
      ..color = ink.hidden;
    canvas.drawRRect(body, scratch);
    return;
  }
  final faded = tone == DieTone.miss;
  final fill = tone == DieTone.hit ? ink.hit : ink.face;
  // The lip: the same shape a hair lower, in shadow, so the die sits ON the
  // card instead of being printed on it.
  scratch
    ..style = PaintingStyle.fill
    ..color = faded ? ink.lip.withValues(alpha: ink.lip.a * 0.4) : ink.lip;
  canvas.drawRRect(body.shift(Offset(0, side * 0.06)), scratch);
  scratch.color = faded ? fill.withValues(alpha: 0.42) : fill;
  canvas.drawRRect(body, scratch);
  if (tone != DieTone.hit) {
    scratch
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, side * 0.025)
      ..color = faded ? ink.edge.withValues(alpha: ink.edge.a * 0.5) : ink.edge;
    canvas.drawRRect(body.deflate(scratch.strokeWidth / 2), scratch);
  }
  if (face < 1 || face > 6) return;
  final pip = tone == DieTone.hit ? ink.hitPip : ink.pip;
  scratch
    ..style = PaintingStyle.fill
    ..color = faded ? pip.withValues(alpha: 0.35) : pip;
  final pr = side * (face == 1 ? 0.12 : 0.095);
  for (final p in _pips[face]) {
    canvas.drawCircle(at + Offset(p.dx * side, p.dy * side), pr, scratch);
  }
}

/// A row of dice, all one size, as one painter.
class DiceRow extends StatelessWidget {
  const DiceRow({
    super.key,
    required this.dice,
    this.size = 40,
    this.gap = 8,
    this.tones,
    this.semanticLabel,
  });

  final List<int> dice;
  final double size;
  final double gap;

  /// Per die; null draws every die plain.
  final List<DieTone>? tones;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final n = dice.length;
    final width = n == 0 ? 0.0 : n * size + (n - 1) * gap;
    return Semantics(
      label: semanticLabel ?? dice.join(', '),
      child: CustomPaint(
        size: Size(width, size * 1.06),
        painter: _DiceRowPainter(
          dice: dice,
          tones: tones,
          size: size,
          gap: gap,
          ink: DiceInk(theme),
        ),
      ),
    );
  }
}

class _DiceRowPainter extends CustomPainter {
  _DiceRowPainter({
    required this.dice,
    required this.tones,
    required this.size,
    required this.gap,
    required this.ink,
  });

  final List<int> dice;
  final List<DieTone>? tones;
  final double size;
  final double gap;
  final DiceInk ink;

  final Paint _scratch = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size box) {
    for (var i = 0; i < dice.length; i++) {
      final tone = tones != null && i < tones!.length
          ? tones![i]
          : DieTone.plain;
      paintDie(
        canvas,
        Offset(i * (size + gap), 0),
        size,
        dice[i],
        tone,
        ink,
        _scratch,
      );
    }
  }

  @override
  bool shouldRepaint(_DiceRowPainter old) =>
      !_sameInts(old.dice, dice) ||
      !_sameTones(old.tones, tones) ||
      old.size != size ||
      old.gap != gap ||
      old.ink != ink;
}

bool _sameInts(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameTones(List<DieTone>? a, List<DieTone>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One die, for a bid ("4 × ⚄") or a face chip.
class DieFace extends StatelessWidget {
  const DieFace({
    super.key,
    required this.face,
    this.size = 28,
    this.tone = DieTone.plain,
  });

  final int face;
  final double size;
  final DieTone tone;

  @override
  Widget build(BuildContext context) =>
      DiceRow(dice: [face], size: size, tones: [tone]);
}

/// A seat's dice cup with how many dice are under it: the plates' count.
///
/// A small leather-brown cup, the shape everyone knows from the real game,
/// with the number on its side. Grey and empty once a seat is out.
class DiceCup extends StatelessWidget {
  const DiceCup({super.key, required this.count, this.size = 22});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final out = count <= 0;
    final body = out
        ? theme.inkMuted
        : (theme.isLight ? const Color(0xFF7A4B2A) : const Color(0xFFB07A4F));
    return SizedBox(
      width: size,
      height: size * 1.08,
      child: CustomPaint(
        painter: _CupPainter(body: body, rim: Color.lerp(body, Colors.black, 0.25)!),
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.28),
          child: Center(
            child: Text(
              out ? '0' : '$count',
              style: TextStyle(
                fontSize: size * 0.5,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter({required this.body, required this.rim});

  final Color body;
  final Color rim;

  Path? _path;
  Size? _for;

  Path _cup(Size s) {
    if (_path != null && _for == s) return _path!;
    final w = s.width;
    final h = s.height;
    // A tapered cup, mouth down: narrow top, wide rim at the bottom.
    _path = Path()
      ..moveTo(w * 0.22, h * 0.10)
      ..quadraticBezierTo(w * 0.5, h * 0.02, w * 0.78, h * 0.10)
      ..lineTo(w * 0.96, h * 0.86)
      ..quadraticBezierTo(w * 0.5, h * 1.0, w * 0.04, h * 0.86)
      ..close();
    _for = s;
    return _path!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = body;
    canvas.drawPath(_cup(size), p);
    p
      ..color = rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.84),
      Offset(size.width * 0.92, size.height * 0.84),
      p,
    );
  }

  @override
  bool shouldRepaint(_CupPainter old) => old.body != body || old.rim != rim;
}
