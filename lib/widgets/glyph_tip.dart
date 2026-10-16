import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// The playful tooltip a toggle says once when it turns on: a dark bubble
// that pops out of the button with an overshoot, a living glyph (the flame
// for "once", the dust for a spoiler) and one short line, gone by itself a
// few seconds later.
//
// Two pieces. [TipBubble] is the bubble at a given age, pure paint, so a
// caller that already runs a clock (the recorder's bloom) drives it from
// that. [GlyphTipAnchor] runs the clock itself and floats the bubble over
// the toggle it wraps, for the toggles that live in ordinary layout (the
// photo composer's send switches).

/// One tip's bubble, [age] seconds into its life.
class TipBubble extends StatelessWidget {
  const TipBubble({
    super.key,
    required this.age,
    required this.text,
    required this.glyph,
    this.growFrom = Alignment.centerRight,
  });

  final double age;
  final String text;

  /// The living mark before the text, already animated by the caller.
  final Widget glyph;

  /// Where on the bubble the button it belongs to is: it grows out of there.
  final Alignment growFrom;

  /// The bubble's fill, which a cut-out glyph (the flame's core) paints in.
  static const Color background = Color(0xF0101012);

  /// How long a tip stays, pop to gone.
  static const double life = 2.9;

  /// The flame's ignition at [age]: lit a beat after the pop, from a spark.
  static double igniteOf(double age) => ((age - 0.08) / 0.5).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final pop = Curves.easeOutBack.transform((age / 0.34).clamp(0.0, 1.0));
    final outT = Curves.easeIn.transform(((age - 2.5) / 0.3).clamp(0.0, 1.0));
    return IgnorePointer(
      child: Opacity(
        opacity: (1 - outT) * (pop.clamp(0.0, 1.0)),
        child: Transform.scale(
          // Grows out of the button it belongs to.
          alignment: growFrom,
          scale: (0.55 + 0.45 * pop) * (1 - 0.15 * outT),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              shadows: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph,
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 210),
                    child: Text(
                      text,
                      maxLines: 2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        letterSpacing: -0.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a toggle and, each time [trigger] changes to a new non-zero value,
/// floats a [TipBubble] above it for [TipBubble.life] seconds.
///
/// The bubble lives in the overlay, anchored to the toggle, so it neither
/// pushes the rail around nor gets clipped by the glass it sits in. Its own
/// ticker runs only while a tip is up. Reduce Motion keeps the bubble and
/// its timing but drops the pop and the glyph's life.
class GlyphTipAnchor extends StatefulWidget {
  const GlyphTipAnchor({
    super.key,
    required this.child,
    required this.text,
    required this.glyph,
    required this.trigger,
  });

  final Widget child;
  final String text;

  /// The bubble's glyph at a running [clock] (seconds, for a flicker) and
  /// the tip's [age].
  final Widget Function(double clock, double age) glyph;

  /// Bump to show the tip. Zero never shows it.
  final int trigger;

  @override
  State<GlyphTipAnchor> createState() => _GlyphTipAnchorState();
}

class _GlyphTipAnchorState extends State<GlyphTipAnchor>
    with SingleTickerProviderStateMixin {
  final GlobalKey _anchor = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _age = ValueNotifier(0);

  @override
  void didUpdateWidget(GlyphTipAnchor old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger != 0) {
      // Not mid-build: the overlay is shown once this frame is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _show();
      });
    }
  }

  void _show() {
    _age.value = 0;
    _ticker.stop();
    _ticker.start();
    _portal.show();
  }

  void _onTick(Duration elapsed) {
    final age = elapsed.inMicroseconds / 1e6;
    if (age >= TipBubble.life) {
      _ticker.stop();
      _portal.hide();
      return;
    }
    _age.value = age;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _bubble,
      child: KeyedSubtree(key: _anchor, child: widget.child),
    );
  }

  /// Above the toggle, kept inside the screen's side margins: centred over
  /// the toggle where there is room, and slid along (growing out of the
  /// toggle's side of it) where there is not.
  Widget _bubble(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder<double>(
      valueListenable: _age,
      builder: (context, age, _) {
        final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
        final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
        if (box == null || overlay == null || !box.attached) {
          return const SizedBox.shrink();
        }
        final at = box.localToGlobal(Offset.zero, ancestor: overlay);
        final width = overlay.size.width;
        const margin = 12.0;
        final centre = at.dx + box.size.width / 2;
        final ax = (((centre - margin) / (width - 2 * margin)) * 2 - 1)
            .clamp(-1.0, 1.0);
        // Calm: in at once, the glyph still, out at once.
        final shown = calm ? (age < 2.8 ? 0.6 : 2.9) : age;
        return Positioned(
          left: margin,
          right: margin,
          bottom: overlay.size.height - at.dy + 10,
          child: Align(
            alignment: Alignment(ax, 1),
            child: Material(
              type: MaterialType.transparency,
              child: TipBubble(
                age: shown,
                text: widget.text,
                growFrom: Alignment(ax, 1),
                glyph: widget.glyph(calm ? 0 : age, calm ? 1 : age),
              ),
            ),
          ),
        );
      },
    );
  }
}
