import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'capture_glyphs.dart' show glyphSpan;
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
class PhotoSendFlight {
  PhotoSendFlight._();

  /// Flies [image]'s [src] region from [from] (global coordinates) into the
  /// next outgoing photo bubble. Takes ownership of [image].
  static void launch(
    BuildContext context, {
    required ui.Image image,
    required Rect src,
    required Rect from,
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
    required this.ticket,
    required this.onDone,
  });

  final ui.Image image;
  final Rect src;
  final Rect from;
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

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _f.addListener(_tick);
    _f.forward().whenComplete(_finish);
  }

  @override
  void dispose() {
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
    final target = ticket.claimed ? ticket.rectIn(space) : null;
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
    );
  }

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
  });

  final Rect rect;
  final double radius;
  final double opacity;
  final double shadow;
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
    final rrect = RRect.fromRectAndRadius(f.rect, Radius.circular(f.radius));
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
