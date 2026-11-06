import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'capture_glyphs.dart' show glyphSpan;
import 'message_bubble.dart' show kCaptionPadding;
import 'send_flight.dart';

/// The photo preview's Send: the picture itself flies down out of the
/// preview into the bubble it becomes, the way a video note's circle does
/// (see `composer_capture.dart`).
///
/// The preview hands over a still of its stage, taken as Send was tapped (the
/// crop, the drawing and the spoiler veil are all in it, because that is what
/// was being looked at), and closes. The still flies in the root overlay,
/// above the preview's route as it leaves, so nothing is on screen twice: the
/// preview hides its own stage the frame the flight starts.
///
/// It leaves at once rather than waiting for its bubble, aimed at where a new
/// outgoing photo usually lands. When the bubble mounts (a frame or two after
/// the preview closes), it claims the flight's [SendFlightTicket] and the
/// flight re-aims at it on every frame, so a list still settling is followed.
/// The bubble stays hidden until the last stretch, then the two cross-fade.
/// No bubble at all (the chat was left, the send refused) and the picture
/// fades out where it got to.
///
/// A caption flies with it. The words leave the preview's caption field and
/// land in the bubble's caption, set in the field's type on the way out and
/// the bubble's on the way in (the two cross-fade mid-air, each scaled to the
/// other's width so neither reflows), on a backing that turns from the
/// field's dark glass into the bubble's fill. The landing holds the whole
/// bubble back, caption included: a caption that was on screen before its
/// picture arrived read as the send arriving in two pieces.
class PhotoSendFlight {
  PhotoSendFlight._();

  /// Flies [image]'s [src] region from [from] (global coordinates) into the
  /// next outgoing photo bubble. Takes ownership of [image].
  ///
  /// [caption], set in [captionStyle] at [captionFrom] (global coordinates,
  /// the text's own box), flies along into the bubble's caption.
  static void launch(
    BuildContext context, {
    required ui.Image image,
    required Rect src,
    required Rect from,
    String? caption,
    Rect? captionFrom,
    TextStyle? captionStyle,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || MediaQuery.disableAnimationsOf(context)) {
      image.dispose();
      return;
    }
    final ticket = SendFlight.open(SendFlightKind.photo);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PhotoFlight(
        image: image,
        src: src,
        from: from,
        caption: caption == null || caption.isEmpty || captionFrom == null
            ? null
            : _Caption(caption, captionFrom, captionStyle ?? const TextStyle()),
        ticket: ticket,
        onDone: () {
          entry.remove();
          image.dispose();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _PhotoFlight extends StatefulWidget {
  const _PhotoFlight({
    required this.image,
    required this.src,
    required this.from,
    required this.caption,
    required this.ticket,
    required this.onDone,
  });

  final ui.Image image;
  final Rect src;
  final Rect from;
  final _Caption? caption;
  final SendFlightTicket ticket;
  final VoidCallback onDone;

  @override
  State<_PhotoFlight> createState() => _PhotoFlightState();
}

class _PhotoFlightState extends State<_PhotoFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _f = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  /// Where the picture is headed this frame: the guess, eased onto the real
  /// bubble once there is one, so a late claim bends the path instead of
  /// jerking it.
  Rect? _aim;

  /// The flight's rect on the last frame, read by the painter.
  late final ValueNotifier<_Frame> _frame = ValueNotifier(
    _Frame(widget.from, radius: 0, opacity: 1, shadow: 0),
  );

  /// The caption's words in each end's type: the preview field's, laid out
  /// at its width once, and the bubble's, laid out again only when the
  /// landing's width changes.
  TextPainter? _srcText;
  TextPainter? _dstText;
  double? _dstWidth;
  TextStyle? _dstStyle;

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _f.addListener(_tick);
    _f.forward().whenComplete(_finish);
  }

  @override
  void dispose() {
    _srcText?.dispose();
    _dstText?.dispose();
    _f.dispose();
    _frame.dispose();
    // Whatever happened, the bubble must not stay hidden.
    widget.ticket.close();
    super.dispose();
  }

  /// A guess at a new outgoing photo's place: right-aligned, just above the
  /// composer, at a bubble's width and the picture's own shape.
  Rect _guess(Size screen) {
    final aspect = widget.from.height / math.max(1, widget.from.width);
    final w = math.min(240.0, screen.width * 0.62);
    final h = math.min(w * aspect, 320.0);
    return Rect.fromLTWH(screen.width - 14 - w, screen.height - 96 - h, w, h);
  }

  void _tick() {
    final space = context.findRenderObject();
    if (space is! RenderBox || !space.hasSize) return;
    final t = _f.value;
    final ticket = widget.ticket;
    final whole = ticket.claimed ? ticket.rectIn(space) : null;
    // The picture's own part of the landing: with a caption the bubble is
    // taller than the photograph, and aiming at the whole of it squashed the
    // picture into the caption's room.
    final target = whole == null
        ? null
        : ticket.partIn(SendFlightPart.media, space) ?? whole;
    final guess = _guess(space.size);
    final aim = _aim ?? guess;
    _aim = target == null
        ? guess
        // Late in the flight, straight onto it: the hand-over must be exact.
        : (t > 0.8 ? target : Rect.lerp(aim, target, 0.35)!);
    final from = space.globalToLocal(widget.from.topLeft) & widget.from.size;
    final rect = _arc(from, _aim!, t);
    final landing = target != null;
    // The bubble shows through over the last stretch; the flight goes with
    // it. Unclaimed, it just fades out.
    final reveal = landing ? glyphSpan(t, 0.72, 1) : 0.0;
    if (landing) ticket.reveal.value = reveal;
    final opacity = landing
        ? 1 - glyphSpan(t, 0.82, 1)
        : 1 - Curves.easeIn.transform(glyphSpan(t, 0.55, 1));
    _frame.value = _Frame(
      rect,
      // From the full-bleed stage's square corners to a bubble's.
      radius: 18 * Curves.easeOut.transform(t),
      opacity: opacity,
      // A small lift as it leaves the stage, gone by the time it lands.
      shadow: math.sin(math.pi * t),
      caption: _captionFrame(space, rect, t, landing ? whole : null),
    );
  }

  /// The caption's pose this frame: its backing, and where its words go.
  _CaptionFrame? _captionFrame(
      RenderBox space, Rect photo, double t, Rect? whole) {
    final c = widget.caption;
    if (c == null) return null;
    final ticket = widget.ticket;
    final src = _srcText ??= TextPainter(
      text: TextSpan(text: c.text, style: c.style),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    )..layout(maxWidth: math.max(1, c.from.width));
    // The words' box as the preview had it, and the glass round them.
    final from = space.globalToLocal(c.from.topLeft) & c.from.size;
    final fromBox = Rect.fromLTRB(
        from.left - 16, from.top - 9, from.right + 14, from.bottom + 9);

    // The bubble's caption once it is measurable; until then, a guess just
    // under the picture at its width.
    final part =
        whole == null ? null : ticket.partIn(SendFlightPart.caption, space);
    final dstStyle = (ticket.textStyle ?? c.style)
        .copyWith(decoration: TextDecoration.none);
    final width = math.max(
        1.0, (part?.width ?? photo.width) - kCaptionPadding.horizontal);
    if (_dstText == null || _dstWidth != width || _dstStyle != dstStyle) {
      _dstText?.dispose();
      _dstWidth = width;
      _dstStyle = dstStyle;
      _dstText = TextPainter(
        text: TextSpan(text: c.text, style: dstStyle),
        textDirection: src.textDirection,
      )..layout(maxWidth: width);
    }
    final dst = _dstText!;

    // Docked under the picture as it flies, not flown on a path of its own:
    // two pieces on two paths drifted apart and overlapped mid-air. It reaches
    // the picture's lower edge a little before the picture lands.
    final k = Curves.easeInOutCubic.transform(glyphSpan(t, 0, 0.75));
    final m = Curves.easeInOutCubic.transform(t);
    final mix = Curves.easeInOut.transform(glyphSpan(t, 0.3, 0.7));
    final left = _lerp(fromBox.left, photo.left, k);
    final boxWidth = _lerp(fromBox.width, photo.width, k);
    final padL = _lerp(16, kCaptionPadding.left, m);
    final padR = _lerp(14, kCaptionPadding.right, m);
    final padT = _lerp(9, kCaptionPadding.top, m);
    final padB = _lerp(9, kCaptionPadding.bottom, m);
    final textWidth = math.max(1.0, boxWidth - padL - padR);
    final srcScale = textWidth / math.max(1.0, src.width);
    final dstScale = textWidth / math.max(1.0, dst.width);
    // As tall as the words it holds this frame, so neither type spills out.
    final textHeight =
        _lerp(src.height * srcScale, dst.height * dstScale, mix);
    final box = Rect.fromLTWH(
      left,
      _lerp(fromBox.top, photo.bottom, k),
      boxWidth,
      padT + textHeight + padB,
    );
    return _CaptionFrame(
      box: box,
      text: box.topLeft + Offset(padL, padT),
      srcScale: srcScale,
      dstScale: dstScale,
      // Mid-air, and quickly: either type held at the wrong scale for long
      // reads as a font glitch.
      mix: mix,
      fill: Color.lerp(
        const Color(0x59000000),
        ticket.color ?? const Color(0x59000000),
        Curves.easeIn.transform(glyphSpan(t, 0.2, 0.8)),
      )!,
      radius: 20 - 2 * m,
      dock: k,
      src: src,
      dst: dst,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Across first, then down, so it swoops into the bubble rather than
  /// sliding along a ruler; the size follows the drop.
  static Rect _arc(Rect from, Rect to, double t) {
    final across = Curves.easeOutCubic.transform(t);
    final down = Curves.easeInOutCubic.transform(t);
    final size = Curves.easeInOutCubic.transform(t);
    final center = Offset(
      from.center.dx + (to.center.dx - from.center.dx) * across,
      from.center.dy + (to.center.dy - from.center.dy) * down,
    );
    return Rect.fromCenter(
      center: center,
      width: from.width + (to.width - from.width) * size,
      height: from.height + (to.height - from.height) * size,
    );
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.ticket.close();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _FlightPainter(
              image: widget.image,
              src: widget.src,
              frame: _frame,
            ),
          ),
        ),
      );
}

class _Frame {
  const _Frame(
    this.rect, {
    required this.radius,
    required this.opacity,
    required this.shadow,
    this.caption,
  });

  final Rect rect;
  final double radius;
  final double opacity;
  final double shadow;
  final _CaptionFrame? caption;
}

/// A caption handed to the flight: its words, where they were, in what type.
class _Caption {
  const _Caption(this.text, this.from, this.style);
  final String text;
  final Rect from;
  final TextStyle style;
}

class _CaptionFrame {
  const _CaptionFrame({
    required this.box,
    required this.text,
    required this.srcScale,
    required this.dstScale,
    required this.mix,
    required this.fill,
    required this.radius,
    required this.dock,
    required this.src,
    required this.dst,
  });

  /// The backing, and the words' top-left inside it.
  final Rect box;
  final Offset text;

  /// Each type's scale to the words' width this frame.
  final double srcScale, dstScale;

  /// 0 all the preview's type, 1 all the bubble's.
  final double mix;
  final Color fill;
  final double radius;

  /// 0 apart, 1 docked under the picture: the seam between the two loses
  /// its corners, so what lands is one bubble and not two pills.
  final double dock;
  final TextPainter src, dst;
}

class _FlightPainter extends CustomPainter {
  _FlightPainter({required this.image, required this.src, required this.frame})
      : super(repaint: frame);

  final ui.Image image;
  final Rect src;
  final ValueNotifier<_Frame> frame;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame.value;
    if (f.opacity <= 0 || f.rect.isEmpty) return;
    final c = f.caption;
    final seam = Radius.circular(f.radius * (1 - (c?.dock ?? 0)));
    final rrect = RRect.fromRectAndCorners(
      f.rect,
      topLeft: Radius.circular(f.radius),
      topRight: Radius.circular(f.radius),
      bottomLeft: seam,
      bottomRight: seam,
    );
    // Under the picture, so the two meet the way the bubble's own photo and
    // caption do: the picture's lower edge over the top of the caption.
    if (c != null) _paintCaption(canvas, c, f.opacity);
    if (f.shadow > 0) {
      canvas.drawRRect(
        rrect.shift(const Offset(0, 6)),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, 0.28 * f.shadow * f.opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawImageRect(
      image,
      _cover(src, f.rect),
      f.rect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, f.opacity),
    );
    canvas.restore();
  }

  static void _paintCaption(Canvas canvas, _CaptionFrame c, double opacity) {
    final seam = Radius.circular(c.radius * (1 - c.dock));
    final backing = RRect.fromRectAndCorners(
      c.box,
      topLeft: seam,
      topRight: seam,
      bottomLeft: Radius.circular(c.radius),
      bottomRight: Radius.circular(c.radius),
    );
    canvas.drawRRect(
      backing,
      Paint()..color = c.fill.withValues(alpha: c.fill.a * opacity),
    );
    // The words stay inside their backing while the two types trade.
    canvas.save();
    canvas.clipRRect(backing);
    void words(TextPainter p, double scale, double alpha) {
      if (alpha <= 0.01) return;
      final size = p.size * scale;
      canvas.saveLayer(
        c.text & Size(size.width + 2, size.height + 2),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      canvas.translate(c.text.dx, c.text.dy);
      canvas.scale(scale);
      p.paint(canvas, Offset.zero);
      canvas.restore();
    }

    words(c.src, c.srcScale, (1 - c.mix) * opacity);
    words(c.dst, c.dstScale, c.mix * opacity);
    canvas.restore();
  }

  /// The middle of [src] at [dst]'s shape: the bubble crops a picture to
  /// fill, so the flight does too, and never stretches it.
  static Rect _cover(Rect src, Rect dst) {
    if (src.isEmpty || dst.isEmpty) return src;
    final da = dst.width / dst.height;
    if (src.width / src.height > da) {
      return Rect.fromCenter(
        center: src.center,
        width: src.height * da,
        height: src.height,
      );
    }
    return Rect.fromCenter(
      center: src.center,
      width: src.width,
      height: src.width / da,
    );
  }

  @override
  bool shouldRepaint(_FlightPainter old) =>
      old.image != image || old.src != src || old.frame != frame;
}
