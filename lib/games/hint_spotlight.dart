/// How a daily board shows a hint: a spotlight on the board and one plain
/// sentence under it.
///
/// The hint used to be a square that silently changed with a 240 ms pop and
/// nothing else. On an empty board that was a square appearing for no stated
/// reason; on a full one it was nearly impossible to even find. Now:
///
///  * everything the hint is not about dims, so the squares that matter stand
///    out however busy the board is ([HintSpotlight]);
///  * the square itself gets a ring (red when it was a mistake) and one soft
///    pulse, so the eye lands on it;
///  * the squares the rule looks at stay lit, and the marks doing the forcing
///    get a thinner ring of their own;
///  * a banner under the board says why, in one line ([HintBanner]).
///
/// Both stay until the player does something on the board or taps the banner
/// away. A flash that is gone before the eye gets there is exactly what made
/// the old hint unreadable.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/games_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import 'game_canvas.dart';

/// A hint as the board draws it.
class BoardHint {
  BoardHint({
    required this.hint,
    required this.serial,
    required this.target,
    this.area = const {},
    this.cause = const {},
  });

  /// From an explained reply. [target] overrides the squares that get the
  /// ring — Flow rings nothing (the lit pipe is the hint), a Queens cross
  /// step rings every square it crossed out.
  factory BoardHint.of(GameHint hint, {required int serial, Set<int>? target}) =>
      BoardHint(
        hint: hint,
        serial: serial,
        target: target ?? {if (hint.cell != null) hint.cell!},
        area: hint.area.toSet(),
        cause: hint.cause.toSet(),
      );

  final GameHint hint;

  /// Bumped per hint, so a second hint replays the entrance.
  final int serial;

  final Set<int> target;
  final Set<int> area;
  final Set<int> cause;

  bool get wrong => hint.kind == GameHintKind.wrong;
}

/// The hint's sentences. Each getter is named after its ARB key, so the
/// reason switch below reads the same as the strings it picks.
class HintCopy {
  const HintCopy(this.l10n);

  final AppLocalizations l10n;

  String get gameHintWrong => l10n.gameHintWrong;
  String get gameHintWrongMore => l10n.gameHintWrongMore;
  String get gameHintWrongLast => l10n.gameHintWrongLast;
  String get gameHintReveal => l10n.gameHintReveal;
  String get gameHintQueensRegion => l10n.gameHintQueensRegion;
  String get gameHintQueensRow => l10n.gameHintQueensRow;
  String get gameHintQueensCol => l10n.gameHintQueensCol;
  String get gameHintQueensRegionInRow => l10n.gameHintQueensRegionInRow;
  String get gameHintQueensRegionInCol => l10n.gameHintQueensRegionInCol;
  String get gameHintQueensRowInRegion => l10n.gameHintQueensRowInRegion;
  String get gameHintQueensColInRegion => l10n.gameHintQueensColInRegion;
  String get gameHintStarsRegion => l10n.gameHintStarsRegion;
  String get gameHintStarsRow => l10n.gameHintStarsRow;
  String get gameHintStarsCol => l10n.gameHintStarsCol;
  String get gameHintTangoEqual => l10n.gameHintTangoEqual;
  String get gameHintTangoCross => l10n.gameHintTangoCross;
  String get gameHintTangoPair => l10n.gameHintTangoPair;
  String get gameHintTangoSandwich => l10n.gameHintTangoSandwich;
  String get gameHintTangoRowSuns => l10n.gameHintTangoRowSuns;
  String get gameHintTangoRowMoons => l10n.gameHintTangoRowMoons;
  String get gameHintTangoColSuns => l10n.gameHintTangoColSuns;
  String get gameHintTangoColMoons => l10n.gameHintTangoColMoons;
  String gameHintLatinBox(int digit) => l10n.gameHintLatinBox(digit);
  String gameHintLatinRow(int digit) => l10n.gameHintLatinRow(digit);
  String gameHintLatinCol(int digit) => l10n.gameHintLatinCol(digit);
  String get gameHintLatinOnly => l10n.gameHintLatinOnly;
  String get gameHintLatinOnlyLines => l10n.gameHintLatinOnlyLines;
  String get gameHintLatinOnlySigns => l10n.gameHintLatinOnlySigns;
  String get gameHintNonogramRowFill => l10n.gameHintNonogramRowFill;
  String get gameHintNonogramRowCross => l10n.gameHintNonogramRowCross;
  String get gameHintNonogramColFill => l10n.gameHintNonogramColFill;
  String get gameHintNonogramColCross => l10n.gameHintNonogramColCross;
  String get gameHintMinesStart => l10n.gameHintMinesStart;
  String get gameHintMinesSafe => l10n.gameHintMinesSafe;
  String get gameHintMinesFlag => l10n.gameHintMinesFlag;
  String get gameHintMinesProofSafe => l10n.gameHintMinesProofSafe;
  String get gameHintMinesProofMine => l10n.gameHintMinesProofMine;
  String get gameHintFlowPipe => l10n.gameHintFlowPipe;
}

/// The banner's main line, and a second one when there is more to say.
(String, String?) hintMessage(AppLocalizations l10n, GameHint hint) {
  final c = HintCopy(l10n);
  if (hint.kind == GameHintKind.wrong) {
    return (
      c.gameHintWrong,
      hint.more > 0 ? c.gameHintWrongMore : c.gameHintWrongLast,
    );
  }
  final d = hint.digit ?? 0;
  final line = switch (hint.reason) {
    'queens.region' => c.gameHintQueensRegion,
    'queens.row' => c.gameHintQueensRow,
    'queens.col' => c.gameHintQueensCol,
    'queens.regionInRow' => c.gameHintQueensRegionInRow,
    'queens.regionInCol' => c.gameHintQueensRegionInCol,
    'queens.rowInRegion' => c.gameHintQueensRowInRegion,
    'queens.colInRegion' => c.gameHintQueensColInRegion,
    'stars.region' => c.gameHintStarsRegion,
    'stars.row' => c.gameHintStarsRow,
    'stars.col' => c.gameHintStarsCol,
    'tango.equal' => c.gameHintTangoEqual,
    'tango.cross' => c.gameHintTangoCross,
    'tango.pair' => c.gameHintTangoPair,
    'tango.sandwich' => c.gameHintTangoSandwich,
    'tango.rowSuns' => c.gameHintTangoRowSuns,
    'tango.rowMoons' => c.gameHintTangoRowMoons,
    'tango.colSuns' => c.gameHintTangoColSuns,
    'tango.colMoons' => c.gameHintTangoColMoons,
    'latin.box' => c.gameHintLatinBox(d),
    'latin.row' => c.gameHintLatinRow(d),
    'latin.col' => c.gameHintLatinCol(d),
    'latin.only' => c.gameHintLatinOnly,
    'latin.onlyLines' => c.gameHintLatinOnlyLines,
    'latin.onlySigns' => c.gameHintLatinOnlySigns,
    'nonogram.rowFill' => c.gameHintNonogramRowFill,
    'nonogram.rowCross' => c.gameHintNonogramRowCross,
    'nonogram.colFill' => c.gameHintNonogramColFill,
    'nonogram.colCross' => c.gameHintNonogramColCross,
    'mines.start' => c.gameHintMinesStart,
    'mines.safe' => c.gameHintMinesSafe,
    'mines.flag' => c.gameHintMinesFlag,
    'mines.proofSafe' => c.gameHintMinesProofSafe,
    'mines.proofMine' => c.gameHintMinesProofMine,
    'flow.pipe' => c.gameHintFlowPipe,
    // A reveal, a reason this build does not know yet, or a server from
    // before explained hints: the square is still spotlit, honestly labelled.
    _ => c.gameHintReveal,
  };
  return (line, null);
}

/// Lays the spotlight over a board. [child] is the board surface; the
/// spotlight never takes a touch, so the board plays exactly as before.
class HintSpotlight extends StatelessWidget {
  const HintSpotlight({
    super.key,
    required this.hint,
    required this.n,
    required this.child,
    this.leadFraction = 0,
  });

  final BoardHint? hint;
  final int n;

  /// Nonogram's clue gutter, as [GameBoardSurface.leadFraction].
  final double leadFraction;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final h = hint;
    if (h == null || n == 0) return child;
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(h.serial),
              tween: Tween(begin: 0, end: 1),
              duration: motion.d(const Duration(milliseconds: 1100)),
              builder: (context, t, _) => CustomPaint(
                painter: HintSpotlightPainter(
                  hint: h,
                  n: n,
                  leadFraction: leadFraction,
                  theme: theme,
                  t: t,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The dim, the lit area, and the rings. See the library comment.
class HintSpotlightPainter extends CustomPainter {
  HintSpotlightPainter({
    required this.hint,
    required this.n,
    required this.leadFraction,
    required this.theme,
    required this.t,
  });

  final BoardHint hint;
  final int n;
  final double leadFraction;
  final AppTheme theme;

  /// 0 → 1 over the entrance: the dim fades in over the first quarter, the
  /// ring settles over the first third, one pulse spreads over the rest.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final lead = side * leadFraction;
    final grid = GameGrid(side: side, n: n, lead: lead);
    final cell = grid.cell;
    final total = n * n;
    bool valid(int i) => i >= 0 && i < total;

    final lit = {...hint.area, ...hint.target, ...hint.cause}.where(valid);
    final fade = Curves.easeOut.transform((t / 0.25).clamp(0.0, 1.0));

    // A lit row or column in Nonogram takes its clues with it: the clue is
    // half of what the reason talks about.
    final gutters = <Rect>[];
    if (lead > 0 && hint.area.isNotEmpty) {
      final rows = hint.area.map((i) => i ~/ n).toSet();
      final cols = hint.area.map((i) => i % n).toSet();
      if (rows.length == 1 && cols.length == n) {
        gutters.add(Rect.fromLTWH(0, lead + rows.first * cell, lead, cell));
      }
      if (cols.length == 1 && rows.length == n) {
        gutters.add(Rect.fromLTWH(lead + cols.first * cell, 0, cell, lead));
      }
    }

    // 1. The dim: the whole square, less every lit square.
    final litPath = Path();
    for (final i in lit) {
      litPath.addRect(grid.rect(i));
    }
    for (final g in gutters) {
      litPath.addRect(g);
    }
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & Size(side, side)),
      litPath,
    );
    final scrim = theme.background.withValues(
      alpha: (theme.background.computeLuminance() > 0.4 ? 0.74 : 0.70) * fade,
    );
    canvas.drawPath(dim, Paint()..color = scrim);

    final tone = hint.wrong ? theme.danger : theme.accent;

    // 2. The area's outline, so a lit row reads as one thing rather than as
    // six squares that happen to be bright.
    final area = hint.area.where(valid).toList();
    if (area.length > 1) {
      // A row, a column or a box is a rectangle, and gets the rounded
      // corners the board's own tiles have; a colour region is traced.
      var bounds = grid.rect(area.first);
      for (final i in area) {
        bounds = bounds.expandToInclude(grid.rect(i));
      }
      final cellsInBounds =
          (bounds.width / cell).round() * (bounds.height / cell).round();
      var outline = Path();
      if (cellsInBounds == area.length) {
        outline.addRRect(
          RRect.fromRectAndRadius(bounds, Radius.circular(cell * 0.18)),
        );
      } else {
        for (final i in area) {
          outline = Path.combine(
            PathOperation.union,
            outline,
            Path()..addRect(grid.rect(i)),
          );
        }
      }
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = tone.withValues(alpha: 0.55 * fade),
      );
    }

    // 3. The marks that force it: a thin ring each.
    final causeRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, cell * 0.035)
      ..color = tone.withValues(alpha: 0.5 * fade);
    for (final i in hint.cause.where(valid)) {
      if (hint.target.contains(i)) continue;
      final r = grid.rect(i).deflate(cell * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell * 0.22)),
        causeRing,
      );
    }

    // 4. The square itself: a ring that lands slightly large and settles,
    // a soft glow under it, and one pulse spreading out and away.
    final ringW = math.max(2.5, cell * 0.075);
    final settle = Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0));
    final grow = 1.25 - 0.25 * settle;
    final pulseT = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
    for (final i in hint.target.where(valid)) {
      final base = grid.rect(i).deflate(ringW / 2 + 1);
      final ring = Rect.fromCenter(
        center: base.center,
        width: base.width * grow,
        height: base.height * grow,
      );
      final radius = Radius.circular(cell * 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(ring, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringW * 2.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..color = tone.withValues(alpha: 0.35 * fade),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(ring, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringW
          ..color = tone.withValues(alpha: fade),
      );
      if (pulseT > 0 && pulseT < 1) {
        final s = 1 + 0.55 * Curves.easeOut.transform(pulseT);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: base.center,
              width: base.width * s,
              height: base.height * s,
            ),
            Radius.circular(cell * 0.2 * s),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringW * (1 - pulseT * 0.6)
            ..color = tone.withValues(alpha: 0.5 * (1 - pulseT)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(HintSpotlightPainter old) =>
      old.hint != hint ||
      old.t != t ||
      old.theme != theme ||
      old.n != n ||
      old.leadFraction != leadFraction;
}

/// The sentence under the board. Pass [hint] null to have nothing there; the
/// slot opens and closes smoothly either way.
class HintBanner extends StatelessWidget {
  const HintBanner({super.key, required this.hint, required this.onDismiss});

  final BoardHint? hint;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final h = hint;
    return AnimatedSize(
      duration: motion.d(theme.motionFast),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: motion.d(theme.motionFast),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        child: h == null
            ? const SizedBox(width: double.infinity, key: ValueKey('none'))
            : Padding(
                key: ValueKey(h.serial),
                padding: const EdgeInsets.only(top: 12),
                child: _BannerCard(hint: h, onDismiss: onDismiss),
              ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.hint, required this.onDismiss});

  final BoardHint hint;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final (line, more) = hintMessage(l10n, hint.hint);
    final tone = hint.wrong ? theme.danger : theme.accent;
    return Semantics(
      liveRegion: true,
      child: SpringPress(
        onTap: onDismiss,
        scale: PressSpec.scaleSmall,
        haptic: false,
        semanticLabel: line,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: groupedFill(theme),
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(color: tone.withValues(alpha: 0.28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hint.wrong
                      ? CupertinoIcons.arrow_counterclockwise
                      : CupertinoIcons.lightbulb_fill,
                  size: 17,
                  color: tone,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentenceCaseOf(context, l10n.gameHint),
                      style: theme.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tone,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: theme.body.copyWith(
                        fontSize: 15,
                        height: 1.3,
                        color: theme.ink,
                      ),
                    ),
                    if (more != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        more,
                        style: theme.bodySoft.copyWith(
                          fontSize: 14,
                          height: 1.3,
                          color: theme.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 14,
                  color: theme.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
