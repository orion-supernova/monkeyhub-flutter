import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/app_theme.dart';
import '../theme/spring.dart';
import '../theme/theme_preference.dart' show AppThemeBrightness;
import 'capture_glyphs.dart';
import 'glass_buttons.dart' show chromeDiscFill;
import 'liquid_glass.dart' show SpecularRim;

/// How the bloom goes away once the recording is over.
enum CaptureBloomExit {
  /// Shrinks back onto the button it grew from: the note went.
  send,

  /// Collapses to nothing: the note was thrown away.
  discard,
}

/// The disc a held record button blooms into, Telegram's way: a 96pt solid
/// accent disc over the composer's button, a halo behind it that breathes
/// with the voice, and the lock pill above it.
///
/// Everything here is measured off a Telegram screen recording (see the
/// capture design spec): the disc's +12% overshoot settling in 250 ms, the
/// halo's fast-rise slow-fall, the pill riding in from behind the disc with a
/// 13pt overshoot, the padlock seating as the finger climbs.
///
/// Driven entirely by its inputs; it never decides anything about the
/// recording. [active] is up; [locked] turns the mic into a send arrow and
/// the disc into the send button; [lockProgress] and [cancelProgress] are the
/// finger. When [active] drops, [exit] picks how it leaves.
///
/// Laid out as a fixed [boxSize] box whose [center] is the button's centre;
/// the host positions it there. Only the disc takes taps, and only when
/// locked.
///
/// One ticker, running only while a spring is moving or the recording is
/// live (the halo and the lock's bob are live loops). At rest, with nothing
/// up, it costs nothing and paints nothing.
class CaptureBloom extends StatefulWidget {
  const CaptureBloom({
    super.key,
    required this.theme,
    required this.active,
    required this.locked,
    required this.lockProgress,
    required this.cancelProgress,
    required this.video,
    required this.level,
    required this.exit,
    required this.onSend,
    required this.sendLabel,
    required this.lockLabel,
  });

  final AppTheme theme;
  final bool active;
  final bool locked;
  final double lockProgress;
  final double cancelProgress;

  /// A video note: a camcorder in the disc, and a breathing halo, there
  /// being no meter.
  final bool video;

  /// The voice, 0..1, every 120 ms. Null for a video note.
  final ValueListenable<double>? level;

  final CaptureBloomExit exit;
  final VoidCallback? onSend;
  final String sendLabel;
  final String lockLabel;

  static const double disc = 96;
  static const Size boxSize = Size(360, 420);
  static const Offset center = Offset(220, 300);

  @override
  State<CaptureBloom> createState() => _CaptureBloomState();
}

class _CaptureBloomState extends State<CaptureBloom> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  /// Seconds the ticker has run, for the live loops.
  double _clock = 0;

  /// The disc's size, as a fraction of [CaptureBloom.disc]. Grows from the
  /// button's own size (44/96) with an overshoot.
  final _scale = Spring(response: 0.18, ratio: 0.58);

  /// The send exit's fade; the discard collapses instead.
  final _fade = Spring(response: 0.2, ratio: 1, value: 1);

  /// The disc trailing the finger: left toward cancel, up toward the lock.
  final _dx = Spring(response: 0.12, ratio: 1);
  final _dy = Spring(response: 0.12, ratio: 1);

  /// The voice, smoothed: quick to rise, slow to fall, as Telegram's does.
  final _level = Spring(response: 0.16, ratio: 1);

  /// Mic (0) to send arrow (1).
  final _morph = Spring(response: 0.3, ratio: 1);

  /// The lock pill: 0 tucked behind the disc, 1 in place.
  final _pill = Spring(response: 0.22, ratio: 0.55);

  double? _lockedAt;
  double? _kickAt;
  bool _calm = false;

  @override
  void initState() {
    super.initState();
    widget.level?.addListener(_onLevel);
    if (widget.active) _enter();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(CaptureBloom old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) {
      old.level?.removeListener(_onLevel);
      widget.level?.addListener(_onLevel);
    }
    if (widget.active && !old.active) {
      _enter();
    } else if (!widget.active && old.active) {
      _leave();
    }
    if (widget.active && widget.locked && !old.locked) {
      _lockedAt = _clock;
      _pill.retarget(1, response: 0.24, ratio: 0.8);
    }
    _wake();
  }

  @override
  void dispose() {
    widget.level?.removeListener(_onLevel);
    _ticker.dispose();
    super.dispose();
  }

  void _enter() {
    _scale
      ..snap(44 / CaptureBloom.disc)
      ..retarget(1, response: 0.18, ratio: 0.58);
    _fade.snap(1);
    _morph.snap(0);
    _dx.snap(0);
    _dy.snap(0);
    _level.snap(0);
    _pill
      ..snap(0)
      ..retarget(1, response: 0.22, ratio: 0.55);
    _lockedAt = null;
    _kickAt = null;
    if (_calm) {
      _scale.snap(1);
      _pill.snap(1);
    }
    _wake();
  }

  void _leave() {
    _pill.retarget(0, response: 0.16, ratio: 1);
    if (widget.exit == CaptureBloomExit.send) {
      _kickAt = _clock;
      _scale.retarget(44 / CaptureBloom.disc, response: 0.3, ratio: 0.82);
      _fade.retarget(0, response: 0.32, ratio: 1);
    } else {
      _scale.retarget(0, response: 0.2, ratio: 1);
    }
    _dx.retarget(0, response: 0.24, ratio: 0.8);
    _dy.retarget(0, response: 0.24, ratio: 0.8);
    if (_calm) {
      _scale.snap(_scale.target);
      _fade.snap(_fade.target);
      _pill.snap(0);
    }
    _wake();
  }

  void _onLevel() {
    final raw = ((widget.level!.value - 0.18) / 0.72).clamp(0.0, 1.0);
    final target = Curves.easeOut.transform(raw);
    // Fast attack, slow release: a word lights it at once and it sinks back
    // over half a second, so speech reads as one swell, not a flicker.
    _level.retarget(target, response: target > _level.value ? 0.16 : 0.45, ratio: 1);
    _wake();
  }

  bool get _live => widget.active;

  bool get _moving =>
      !_scale.atRest ||
      !_fade.atRest ||
      !_dx.atRest ||
      !_dy.atRest ||
      !_level.atRest ||
      !_morph.atRest ||
      !_pill.atRest ||
      _kickAt != null;

  void _wake() {
    if ((_live && !_calm) || _moving) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _clock += dt;

    if (widget.active) {
      final away = widget.locked ? 0.0 : widget.cancelProgress.clamp(0.0, 1.0);
      final up = widget.locked ? 0.0 : widget.lockProgress.clamp(0.0, 1.0);
      _dx.retarget(-away * CaptureBloom.disc);
      _dy.retarget(-up * 64, response: widget.locked ? 0.24 : 0.12, ratio: widget.locked ? 0.72 : 1);
      final lockedAt = _lockedAt;
      if (lockedAt != null && _clock - lockedAt > 0.12) _morph.retarget(1);
      // The padlock holds closed a moment once latched, then goes.
      if (lockedAt != null && _clock - lockedAt > 0.3) _pill.retarget(0, response: 0.18, ratio: 1);
    }
    if (_kickAt != null && _clock - _kickAt! > 0.24) _kickAt = null;

    for (final s in [_scale, _fade, _dx, _dy, _level, _morph, _pill]) {
      s.tick(dt);
    }
    if (!((_live && !_calm) || _moving)) _ticker.stop();
    setState(() {});
  }

  /// The halo's level: the voice, or a slow breath for a video note.
  double get _haloLevel {
    if (_calm) return 0.25;
    if (widget.level == null) {
      return 0.12 + 0.18 * (0.5 - 0.5 * math.cos(2 * math.pi * _clock / 1.8));
    }
    return math.max(0.08, _level.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final scale = _scale.value;
    if (scale <= 0.001 && !widget.active) return SizedBox.fromSize(size: CaptureBloom.boxSize);

    final cancel = widget.locked ? 0.0 : widget.cancelProgress.clamp(0.0, 1.0);
    // Shrinks toward the bin as the finger slides: 96 down to 45 at the line.
    final shrink = 1 - (1 - 0.47) * Curves.easeOut.transform(cancel);
    final d = CaptureBloom.disc * scale * shrink;
    final c = CaptureBloom.center + Offset(_dx.value, _dy.value);
    final fade = _fade.value.clamp(0.0, 1.0);
    final halo = _haloLevel;
    final haloAlpha = (1 - cancel) * fade * scale.clamp(0.0, 1.0);

    return SizedBox.fromSize(
      size: CaptureBloom.boxSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_pill.value > 0.01) _lockPill(theme),
          IgnorePointer(
            child: Stack(
              children: [
                _haloRing(c, d / 2 + 10 + 16 * halo, 0.13 * haloAlpha),
                _haloRing(c, d / 2 + 4 + 9 * halo, 0.28 * haloAlpha),
              ],
            ),
          ),
          Positioned(
            left: c.dx - d / 2,
            top: c.dy - d / 2,
            width: d,
            height: d,
            child: _disc(theme, d, fade),
          ),
        ],
      ),
    );
  }

  Widget _haloRing(Offset c, double r, double alpha) {
    if (alpha <= 0.002 || r <= 0) return const SizedBox.shrink();
    final accent = widget.theme.accent;
    // A soft 6pt edge from a gradient, never a blur filter.
    final edge = (1 - 6 / r).clamp(0.0, 1.0);
    return Positioned(
      left: c.dx - r,
      top: c.dy - r,
      width: r * 2,
      height: r * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              accent.withValues(alpha: alpha),
              accent.withValues(alpha: alpha),
              accent.withValues(alpha: 0),
            ],
            stops: [0, edge, 1],
          ),
        ),
      ),
    );
  }

  Widget _disc(AppTheme theme, double d, double fade) {
    final ink = theme.accentInk;
    final m = _morph.value.clamp(0.0, 1.0);
    // Mic out (scale down, fade) then the arrow draws itself in.
    final micT = (m / 0.35).clamp(0.0, 1.0);
    final arrowT = ((m - 0.35) / 0.65).clamp(0.0, 1.0);
    final kickAt = _kickAt;
    final kick = kickAt == null
        ? 0.0
        : math.sin(math.pi * Curves.easeOut.transform(((_clock - kickAt) / 0.24).clamp(0.0, 1.0)));
    final glyphSize = 28 * (d / CaptureBloom.disc).clamp(0.4, 1.2);
    final glyphIn = ((_scale.value - 0.46) / 0.54).clamp(0.0, 1.0);

    Widget glyph;
    if (widget.video && m == 0) {
      glyph = VideoNoteGlyph(color: ink, size: glyphSize);
    } else {
      glyph = Stack(
        alignment: Alignment.center,
        children: [
          if (micT < 1)
            Opacity(
              opacity: 1 - micT,
              child: Transform.scale(
                scale: 1 - 0.6 * micT,
                child: widget.video
                    ? VideoNoteGlyph(color: ink, size: glyphSize)
                    // The capsule fills with the voice: a meter in the glyph.
                    : MicGlyph(color: ink, size: glyphSize, level: 0.15 + 0.7 * _level.value),
              ),
            ),
          if (arrowT > 0)
            Transform.translate(
              offset: Offset(0, -6 * kick),
              child: Transform.scale(
                scale: 0.7 + 0.3 * Curves.easeOutBack.transform(arrowT),
                child: SendArrowGlyph(color: ink, t: arrowT, size: glyphSize),
              ),
            ),
        ],
      );
    }

    final body = Opacity(
      opacity: fade,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.35 * fade),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Opacity(
            opacity: glyphIn,
            child: Transform.scale(scale: 0.6 + 0.4 * glyphIn, child: glyph),
          ),
        ),
      ),
    );

    if (!widget.locked || !widget.active) return IgnorePointer(child: body);
    // Locked, the disc IS the send button.
    return FocusableTap(
      onTap: widget.onSend,
      semanticLabel: widget.sendLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSend,
        child: body,
      ),
    );
  }

  /// The still-chrome capsule above the disc: a padlock whose shackle seats
  /// as the finger climbs, over a chevron that bobs while nothing is
  /// happening yet. It compresses from 72pt tall to a 40pt circle as the
  /// finger approaches, then holds closed a moment once latched and goes.
  Widget _lockPill(AppTheme theme) {
    final p = widget.locked ? 1.0 : widget.lockProgress.clamp(0.0, 1.0);
    final pill = _pill.value;
    final height = 72 - 32 * p;
    final idle = widget.active && !widget.locked && p < 0.05 && !_calm;
    final bob = idle ? math.sin(2 * math.pi * _clock / 1.2) : 0.0;
    final cx = CaptureBloom.center.dx;
    // Rides in from behind the disc; its top edge stays put as it compresses.
    final top = CaptureBloom.center.dy - 122 - 36 + (1 - pill) * 70;
    final ink = theme.ink;

    return Positioned(
      left: cx - 20,
      top: top,
      width: 40,
      height: height,
      child: IgnorePointer(
        child: Semantics(
          label: widget.lockLabel,
          value: '${(p * 100).round()}%',
          child: Opacity(
            // In quickly; out by fading first, so it never hangs about as a
            // ghost while it sinks.
            opacity: (widget.active && widget.lockProgress < 1 && !widget.locked ? pill * 1.6 : pill * pill).clamp(0.0, 1.0),
            child: CustomPaint(
              painter: _PillPainter(theme: theme),
              child: Column(
                children: [
                  SizedBox(height: 12 + 6 * p),
                  Transform.translate(
                    offset: Offset(0, -bob * 0.5),
                    child: PadlockGlyph(closed: p, size: 22, color: ink),
                  ),
                  if (p < 0.5) ...[
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: (1 - p / 0.5).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -6 * p - 2 * (0.5 + 0.5 * bob)),
                        child: ChevronGlyph(direction: AxisDirection.up, size: 16, color: theme.inkMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lock's capsule: the same still chrome as every disc in the app, its
/// fill and its lit rim, so it reads as one of our buttons and not a sticker.
class _PillPainter extends CustomPainter {
  const _PillPainter({required this.theme});

  final AppTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width / 2));
    canvas.drawRRect(
      rrect.shift(Offset(0, theme.isLight ? 1 : 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: theme.isLight ? 0.10 : 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(rrect, Paint()..color = chromeDiscFill(theme));
    SpecularRim(shape: const StadiumBorder(), light: theme.isLight).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_PillPainter old) => old.theme != theme;
}
