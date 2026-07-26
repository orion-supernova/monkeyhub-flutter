import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The shape family a message bubble is drawn with. Orthogonal to the theme:
/// a theme owns colour, border and shadow, this owns geometry, so every style
/// below looks native in all nine themes.
enum BubbleStyle {
  /// A tail closes each run of messages, and the corners on the sender's side
  /// tighten on the rows above it so the run reads as one connected block.
  ///
  /// The tail is a single convex sweep off the corner into a point — no
  /// undercut tucked beneath it. Curved hooks and comic-book spikes were both
  /// tried and both read worse at message size: the hook smeared into an
  /// eyebrow along the bubble's bottom, the spike into a nub.
  tailed,

  /// Rounded bubbles with no tail — runs connect only through their tightened
  /// inner corners. The look this app shipped before tails existed.
  soft,

  /// Fully rounded capsules, identical on every row.
  pill,

  /// Square-shouldered bubbles at the theme's small radius.
  slab,
}

/// How far the tail juts past the bubble body, derived from the theme's own
/// large corner radius so a 20pt-radius theme gets a generous tail and a 4pt
/// brutalist theme gets a small sharp one.
double bubbleTailWidth(double largeRadius) =>
    (largeRadius * 0.55).clamp(5.0, 9.0);

/// A message bubble outline: a rounded rect with independently-sized corners
/// and, optionally, an iMessage-style curved tail on the sender's side.
///
/// The tail is drawn *inside* the widget's rect rather than spilling out of
/// it. [dimensions] reserves a gutter of [tailWidth] on the sender's side,
/// which `Container` adds to its own padding automatically (a `Decoration`'s
/// padding is honoured by every `Container`), and the bubble *body* always
/// stops at that gutter — whether this particular bubble draws a tail or not.
/// That is what keeps the bodies of a run flush with each other while only the
/// closing bubble's tail reaches into the gutter.
@immutable
class BubbleShape extends ShapeBorder {
  const BubbleShape({
    required this.radii,
    required this.isMine,
    this.tail = false,
    this.tailWidth = 0,
    this.tailHeight = 0,
    this.side = BorderSide.none,
  });

  /// Corner radii in absolute (visual) terms — already resolved for
  /// mine/theirs and for this row's position in its run.
  final BorderRadius radii;

  /// Outgoing messages hang their tail off the right edge, incoming off the
  /// left. Also decides which side the gutter is reserved on.
  final bool isMine;

  /// Whether *this* bubble draws the tail. False on every row of a run except
  /// the last one.
  final bool tail;

  final double tailWidth;

  /// How far up the body's edge the tail sets off.
  final double tailHeight;

  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.fromLTRB(
        side.width + (isMine ? 0 : tailWidth),
        side.width,
        side.width + (isMine ? tailWidth : 0),
        side.width,
      );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    // Stroke down the middle of the outline, matching how `Border.all` reads
    // in the flat decoration this replaces.
    canvas.drawPath(
      _path(rect.deflate(side.width / 2)),
      side.toPaint()..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) => BubbleShape(
        radii: radii * t,
        isMine: isMine,
        tail: tail,
        tailWidth: tailWidth * t,
        tailHeight: tailHeight * t,
        side: side.scale(t),
      );

  /// The outline, built canonically with the tail on the right and mirrored
  /// for incoming messages — one piece of geometry to get right instead of two
  /// hand-mirrored ones.
  Path _path(Rect rect) {
    final canonical = _canonicalPath(rect);
    if (isMine) return canonical;
    return canonical.transform(
      (Matrix4.identity()
            ..translateByDouble(2 * rect.center.dx, 0, 0, 1)
            ..scaleByDouble(-1, 1, 1, 1))
          .storage,
    );
  }

  Path _canonicalPath(Rect rect) {
    // Mirroring the path also mirrors the corners, so the canonical build
    // takes the radii pre-flipped for incoming bubbles.
    final r = isMine ? radii : _flip(radii);
    final body = Rect.fromLTRB(
      rect.left,
      rect.top,
      math.max(rect.left, rect.right - tailWidth),
      rect.bottom,
    );
    if (body.width <= 0 || body.height <= 0) {
      return Path()..addRect(body);
    }

    final cap = math.min(body.width, body.height) / 2;
    double c(Radius v) => v.x.clamp(0.0, cap);
    final tl = c(r.topLeft);
    final tr = c(r.topRight);
    final br = c(r.bottomRight);
    final bl = c(r.bottomLeft);

    final p = Path()..moveTo(body.left + tl, body.top);
    p.lineTo(body.right - tr, body.top);
    p.arcToPoint(Offset(body.right, body.top + tr),
        radius: Radius.circular(tr));

    if (tail && tailWidth > 0) {
      _appendTail(p, body, br: br, bl: bl);
    } else {
      p.lineTo(body.right, body.bottom - br);
      p.arcToPoint(Offset(body.right - br, body.bottom),
          radius: Radius.circular(br));
    }

    p.lineTo(body.left + bl, body.bottom);
    p.arcToPoint(Offset(body.left, body.bottom - bl),
        radius: Radius.circular(bl));
    p.lineTo(body.left, body.top + tl);
    p.arcToPoint(Offset(body.left + tl, body.top),
        radius: Radius.circular(tl));
    return p..close();
  }

  /// Draws the tail into [p], which is sitting at the top of the body's right
  /// edge. It sets off down that edge, sweeps out to a point [tailWidth] past
  /// it, and runs straight back into the bottom edge, from where the caller
  /// carries on to the bottom-left corner.
  ///
  /// One convex sweep, no undercut. The tail replaces the bottom corner rather
  /// than hanging off it, so it stays small — never taller than the bubble, or
  /// a one-liner would be all tail.
  void _appendTail(Path p, Rect body, {required double br, required double bl}) {
    final w = tailWidth;
    final h = math.min(tailHeight, body.height * 0.85);
    // Where it rejoins the bottom edge. Kept tight: reach further in and the
    // tail flattens into an eyebrow drawn across the bubble's bottom instead
    // of a tail hanging off its corner.
    final rejoin = math.max(body.left + bl, body.right - w * 0.45);

    p.lineTo(body.right, body.bottom - math.min(br, h));
    p.cubicTo(
      body.right, body.bottom - h * 0.40,
      body.right + w * 0.70, body.bottom - h * 0.30,
      body.right + w, body.bottom,
    );
    p.lineTo(rejoin, body.bottom);
  }

  static BorderRadius _flip(BorderRadius r) => BorderRadius.only(
        topLeft: r.topRight,
        topRight: r.topLeft,
        bottomLeft: r.bottomRight,
        bottomRight: r.bottomLeft,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BubbleShape &&
          other.radii == radii &&
          other.isMine == isMine &&
          other.tail == tail &&
          other.tailWidth == tailWidth &&
          other.tailHeight == tailHeight &&
          other.side == side;

  @override
  int get hashCode =>
      Object.hash(radii, isMine, tail, tailWidth, tailHeight, side);
}

/// Re-shapes what a theme authored into a [BubbleShape] for this row's
/// position in its run.
///
/// The corner sizes come from the theme's *own* decoration — its large corner
/// and its small corner — so Cyberpunk stays 6/2 and Retro Wave stays 4/0.
/// Only which corner gets which size (and whether a tail is drawn) is decided
/// here.
BubbleShape bubbleShapeFrom(
  BoxDecoration base, {
  required BubbleStyle style,
  required bool isMine,
  bool firstInRun = true,
  bool lastInRun = true,
}) {
  final authored =
      base.borderRadius?.resolve(TextDirection.ltr) ?? BorderRadius.zero;
  final corners = <double>[
    authored.topLeft.x,
    authored.topRight.x,
    authored.bottomLeft.x,
    authored.bottomRight.x,
  ];
  final big = corners.reduce(math.max);
  final small = corners.reduce(math.min);

  // Every theme uses `Border.all` today; the uniformity guard just keeps a
  // future one-sided border from being silently stroked all the way round.
  final b = base.border;
  final side = (b is Border && b.isUniform) ? b.top : BorderSide.none;

  final BorderRadius radii;
  var tail = false;
  var gutter = 0.0;
  switch (style) {
    case BubbleStyle.tailed:
      radii = _runAware(
        isMine: isMine,
        far: big,
        senderTop: firstInRun ? big : small,
        senderBottom: lastInRun ? big : small,
      );
      tail = lastInRun;
      // Reserved whether or not this row draws the tail, so the bodies of a
      // run stay flush with one another.
      gutter = bubbleTailWidth(big);
    case BubbleStyle.soft:
      radii = _runAware(
        isMine: isMine,
        far: big,
        senderTop: firstInRun ? big : small,
        senderBottom: small,
      );
    case BubbleStyle.pill:
      // Capped to half the bubble's height at paint time, so a one-liner is a
      // true capsule and a paragraph stays a generously rounded rect.
      radii = BorderRadius.circular(math.max(big, 22));
    case BubbleStyle.slab:
      radii = BorderRadius.circular(small);
  }

  return BubbleShape(
    radii: radii,
    isMine: isMine,
    tail: tail,
    tailWidth: gutter,
    tailHeight: gutter * 1.4,
    side: side,
  );
}

BorderRadius _runAware({
  required bool isMine,
  required double far,
  required double senderTop,
  required double senderBottom,
}) =>
    BorderRadius.only(
      topLeft: Radius.circular(isMine ? far : senderTop),
      topRight: Radius.circular(isMine ? senderTop : far),
      bottomLeft: Radius.circular(isMine ? far : senderBottom),
      bottomRight: Radius.circular(isMine ? senderBottom : far),
    );
