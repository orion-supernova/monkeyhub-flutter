/// The chess piece set: original vector silhouettes, drawn as [Path]s.
///
/// Drawn from scratch for this app on purpose. The familiar free sets
/// (cburnett, merida and friends) are GPL or CC-BY-SA, and the app is sold,
/// so nothing here is traced from or modelled on any of them: each piece is a
/// union of a few plain primitives (rounded rects, circles, two or three
/// curves), which is also what keeps them clean at 12 pt in a chat
/// thumbnail.
///
/// Every path lives in a unit square, y down, standing on a shared two-step
/// plinth. A painter scales the canvas to the square and draws the
/// silhouette once filled and once stroked; the internal detail lines (a
/// collar, a mitre's cut, a mane) are a second, thinner stroke. Built once
/// per isolate and shared by every board.
library;

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../chess.dart';

/// A piece's silhouette and its interior detail lines, unit square.
class ChessPieceArt {
  const ChessPieceArt(this.silhouette, this.detail);

  final Path silhouette;
  final Path detail;
}

Path _rr(double l, double t, double r, double b, double radius) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

Path _circle(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

Path _union(List<Path> parts) =>
    parts.reduce((a, b) => Path.combine(PathOperation.union, a, b));

Path _minus(Path a, Path b) => Path.combine(PathOperation.difference, a, b);

Path _poly(List<Offset> points) => Path()..addPolygon(points, true);

/// The plinth every piece stands on: a wide foot and a narrower step.
Path _plinth() => _union([
  _rr(0.21, 0.80, 0.79, 0.90, 0.04),
  _rr(0.27, 0.735, 0.73, 0.815, 0.03),
]);

/// The line where the step meets the foot, so the plinth reads as two
/// pieces of turned wood rather than one blob.
Path _plinthDetail() => Path()
  ..moveTo(0.29, 0.805)
  ..lineTo(0.71, 0.805);

ChessPieceArt _pawn() {
  final body = Path()
    ..moveTo(0.335, 0.75)
    ..cubicTo(0.36, 0.63, 0.415, 0.585, 0.43, 0.51)
    ..lineTo(0.57, 0.51)
    ..cubicTo(0.585, 0.585, 0.64, 0.63, 0.665, 0.75)
    ..close();
  final collar = _rr(0.355, 0.465, 0.645, 0.525, 0.03);
  return ChessPieceArt(
    _union([_plinth(), body, collar, _circle(0.5, 0.345, 0.13)]),
    _plinthDetail()..addRRect(RRect.fromLTRBR(0.355, 0.465, 0.645, 0.525, const Radius.circular(0.03))),
  );
}

ChessPieceArt _rook() {
  final body = _poly(const [
    Offset(0.335, 0.75),
    Offset(0.37, 0.44),
    Offset(0.63, 0.44),
    Offset(0.665, 0.75),
  ]);
  var top = _rr(0.27, 0.17, 0.73, 0.41, 0.035);
  // Three merlons: two notches cut down from the top edge.
  for (final x in const [0.385, 0.545]) {
    top = _minus(top, _rr(x, 0.12, x + 0.07, 0.265, 0.018));
  }
  final collar = _rr(0.31, 0.395, 0.69, 0.46, 0.025);
  return ChessPieceArt(
    _union([_plinth(), body, top, collar]),
    _plinthDetail()
      ..addRRect(RRect.fromLTRBR(0.31, 0.395, 0.69, 0.46, const Radius.circular(0.025))),
  );
}

ChessPieceArt _bishop() {
  final body = Path()
    ..moveTo(0.37, 0.75)
    ..cubicTo(0.30, 0.62, 0.285, 0.43, 0.5, 0.215)
    ..cubicTo(0.715, 0.43, 0.70, 0.62, 0.63, 0.75)
    ..close();
  // The mitre's cut: a slot from the upper right towards the centre.
  final slit = _poly(const [
    Offset(0.585, 0.315),
    Offset(0.625, 0.355),
    Offset(0.505, 0.475),
    Offset(0.465, 0.435),
  ]);
  final collar = _rr(0.335, 0.66, 0.665, 0.725, 0.03);
  return ChessPieceArt(
    _union([_plinth(), _minus(body, slit), collar, _circle(0.5, 0.17, 0.055)]),
    _plinthDetail()
      ..addRRect(RRect.fromLTRBR(0.335, 0.66, 0.665, 0.725, const Radius.circular(0.03))),
  );
}

ChessPieceArt _knight() {
  // A horse's head in profile, facing left: chest, throat, jaw, a rounded
  // muzzle, the long line of the nose to one pricked ear, and the mane
  // falling down the back of the neck.
  final head = Path()
    ..moveTo(0.31, 0.75)
    ..cubicTo(0.30, 0.66, 0.35, 0.585, 0.43, 0.535)
    ..cubicTo(0.37, 0.53, 0.31, 0.555, 0.255, 0.55)
    ..cubicTo(0.19, 0.545, 0.155, 0.50, 0.17, 0.445)
    ..cubicTo(0.20, 0.36, 0.29, 0.26, 0.40, 0.205)
    ..lineTo(0.445, 0.085)
    ..cubicTo(0.475, 0.10, 0.51, 0.15, 0.525, 0.19)
    ..cubicTo(0.65, 0.23, 0.73, 0.34, 0.735, 0.47)
    ..cubicTo(0.74, 0.58, 0.715, 0.67, 0.69, 0.75)
    ..close();
  final eye = _circle(0.365, 0.325, 0.03);
  final mane = Path()
    ..moveTo(0.54, 0.25)
    ..cubicTo(0.62, 0.32, 0.665, 0.45, 0.635, 0.70);
  return ChessPieceArt(
    _union([_plinth(), _minus(head, eye)]),
    _plinthDetail()..addPath(mane, Offset.zero),
  );
}

ChessPieceArt _queen() {
  // A five-point crown: the tips lean out, the centre one stands tallest.
  final body = _poly(const [
    Offset(0.335, 0.75),
    Offset(0.205, 0.31),
    Offset(0.31, 0.45),
    Offset(0.35, 0.215),
    Offset(0.435, 0.415),
    Offset(0.5, 0.175),
    Offset(0.565, 0.415),
    Offset(0.65, 0.215),
    Offset(0.69, 0.45),
    Offset(0.795, 0.31),
    Offset(0.665, 0.75),
  ]);
  final band = _rr(0.29, 0.585, 0.71, 0.65, 0.03);
  return ChessPieceArt(
    _union([
      _plinth(),
      body,
      band,
      for (final (x, y) in const [
        (0.205, 0.31),
        (0.35, 0.215),
        (0.5, 0.175),
        (0.65, 0.215),
        (0.795, 0.31),
      ])
        _circle(x, y, 0.05),
    ]),
    _plinthDetail()
      ..addRRect(RRect.fromLTRBR(0.29, 0.585, 0.71, 0.65, const Radius.circular(0.03))),
  );
}

ChessPieceArt _king() {
  // Two lobes either side of a pillar, under a cross.
  final body = Path()
    ..moveTo(0.335, 0.75)
    ..cubicTo(0.30, 0.64, 0.235, 0.53, 0.245, 0.43)
    ..cubicTo(0.255, 0.32, 0.41, 0.28, 0.5, 0.385)
    ..cubicTo(0.59, 0.28, 0.745, 0.32, 0.755, 0.43)
    ..cubicTo(0.765, 0.53, 0.70, 0.64, 0.665, 0.75)
    ..close();
  final band = _rr(0.29, 0.61, 0.71, 0.675, 0.03);
  return ChessPieceArt(
    _union([
      _plinth(),
      body,
      band,
      _rr(0.445, 0.25, 0.555, 0.42, 0.03),
      _rr(0.462, 0.055, 0.538, 0.285, 0.022),
      _rr(0.395, 0.115, 0.605, 0.19, 0.022),
    ]),
    _plinthDetail()
      ..addRRect(RRect.fromLTRBR(0.29, 0.61, 0.71, 0.675, const Radius.circular(0.03)))
      ..moveTo(0.5, 0.42)
      ..lineTo(0.5, 0.60),
  );
}

/// Art by piece type, [chessPawn] through [chessKing]; index 0 is unused.
final List<ChessPieceArt?> chessPieceArt = [
  null,
  _pawn(),
  _knight(),
  _bishop(),
  _rook(),
  _queen(),
  _king(),
];

/// The four colours a side is drawn in, and the paints built from them.
///
/// White is filled light with a dark rim and black filled dark with a light
/// rim, as asked; both fills carry a faint top-to-bottom shade so a piece
/// reads as turned and solid rather than as a sticker, and both rims are
/// fixed greys rather than theme colours, because a piece's colour is the
/// game's information and must not drift with the theme. What follows the
/// theme is only black's rim: a mid grey on a dark board, where it is what
/// separates a black piece from a dark square (pure white there turned every
/// black piece into an outline icon, render-checked), near white on a light
/// one, where the dark fill already carries it.
class ChessPieceStyle {
  ChessPieceStyle({required bool darkTheme})
    : _rims = [
        const Color(0xFF232326),
        darkTheme ? const Color(0xFFB9B9C1) : const Color(0xFFD9D9DE),
      ];

  static final _fills = [
    ui.Gradient.linear(const Offset(0, 0.12), const Offset(0, 0.9), const [
      Color(0xFFFFFFFF),
      Color(0xFFE9E9E6),
    ]),
    ui.Gradient.linear(const Offset(0, 0.12), const Offset(0, 0.9), const [
      Color(0xFF48484E),
      Color(0xFF17171A),
    ]),
  ];

  final List<Color> _rims;

  /// Rim width in unit-square terms: about 1.5 pt on a 36 pt square, which
  /// still leaves a visible edge at 12 pt.
  static const double rimWidth = 0.05;

  /// Paints [type] for [side] into the unit square, which the caller has
  /// scaled the canvas to. [alpha] fades it (a captured piece going).
  void paint(Canvas canvas, int type, int side, {double alpha = 1, bool shadow = true}) {
    final art = chessPieceArt[type];
    if (art == null || alpha <= 0) return;
    final fade = alpha < 1;
    if (fade) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    if (shadow) {
      // A soft contact shadow: the silhouette, nudged down, at low alpha.
      canvas.save();
      canvas.translate(0, 0.025);
      canvas.drawPath(art.silhouette, Paint()..color = const Color(0x2E000000));
      canvas.restore();
    }
    canvas.drawPath(art.silhouette, Paint()..shader = _fills[side]);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = _rims[side]
      // Black's light rim a hair thinner: at full width it outweighs the
      // dark fill and the piece reads as hollow.
      ..strokeWidth = side == 0 ? rimWidth : rimWidth * 0.84;
    canvas.drawPath(art.silhouette, rim);
    rim
      ..strokeWidth = rimWidth * 0.62
      ..color = _rims[side].withValues(alpha: 0.85);
    canvas.drawPath(art.detail, rim);
    if (fade) canvas.restore();
  }
}
