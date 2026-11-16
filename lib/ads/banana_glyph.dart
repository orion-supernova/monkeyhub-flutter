import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The banana: the platform's own 🍌 (Apple's on iOS and macOS, Google's on
/// Android, Microsoft's on Windows; Linux and the web use whatever emoji font
/// they have, as every other emoji in the app does), with motion on top.
///
/// A drawn banana was tried at length (2026-11-16, see git history of this
/// file) and never got close enough to the system one to be worth its 600
/// lines; a currency glyph may differ a little per platform, as emoji do.
///
/// Two motions, in the playful-glyph spirit:
///  * [popKey] changes → a pop: the banana jumps, overshoots and wobbles to
///    rest. For the moment bananas land.
///  * [waving] → an idle wave every couple of seconds, while there is
///    something waiting (today's free banana). Only for that live state; it
///    stops the moment it is false, and never runs under Reduce Motion.
class BananaGlyph extends StatefulWidget {
  const BananaGlyph({
    super.key,
    this.size = 20,
    this.popKey = 0,
    this.waving = false,
  });

  final double size;

  /// Bump to pop (e.g. the balance after a credit).
  final int popKey;
  final bool waving;

  @override
  State<BananaGlyph> createState() => _BananaGlyphState();
}

class _BananaGlyphState extends State<BananaGlyph>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWave();
  }

  @override
  void didUpdateWidget(BananaGlyph old) {
    super.didUpdateWidget(old);
    if (old.popKey != widget.popKey && !_still) _pop.forward(from: 0);
    if (old.waving != widget.waving) _syncWave();
  }

  void _syncWave() {
    if (widget.waving && !_still) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
      _wave.value = 0;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: s,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pop, _wave]),
          // Laid out once; the motion only transforms it.
          child: FittedBox(
            child: Text(
              '🍌',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: s, height: 1),
            ),
          ),
          builder: (context, child) {
            final p = _pop.value;
            final lift =
                p == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(p));
            final wobble =
                p == 0 ? 0.0 : math.sin(p * math.pi * 5) * (1 - p) * 0.3;
            // Wave: two quick swings at the start of each cycle, then rest.
            final w = _wave.value;
            final wave =
                w < 0.32 ? math.sin(w / 0.32 * math.pi * 2) * 0.16 : 0.0;
            return Transform.translate(
              offset: Offset(0, -s * 0.10 * lift),
              child: Transform.rotate(
                angle: wobble + wave,
                alignment: const Alignment(0, 0.6),
                child: Transform.scale(scale: 1 + 0.26 * lift, child: child),
              ),
            );
          },
        ),
      ),
    );
  }
}
