import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/input.dart';

/// Live input from every source, merged into one engine bitmask ([Inp]).
class FightInput {
  int touch = 0;
  final Set<LogicalKeyboardKey> _keys = {};

  int get mask => touch | _keyMask();

  void clear() {
    touch = 0;
    _keys.clear();
  }

  /// Held-key tracking is ours, not HardwareKeyboard's: key-ups get lost when
  /// the window loses focus mid-press, so [clear] on focus loss resets it.
  KeyEventResult onKey(KeyEvent e) {
    final k = e.logicalKey;
    if (!_bits.containsKey(k)) return KeyEventResult.ignored;
    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      _keys.add(k);
    } else if (e is KeyUpEvent) {
      _keys.remove(k);
    }
    return KeyEventResult.handled;
  }

  int _keyMask() {
    var m = 0;
    for (final k in _keys) {
      m |= _bits[k] ?? 0;
    }
    return m;
  }

  static final Map<LogicalKeyboardKey, int> _bits = {
    LogicalKeyboardKey.keyA: Inp.left,
    LogicalKeyboardKey.arrowLeft: Inp.left,
    LogicalKeyboardKey.keyD: Inp.right,
    LogicalKeyboardKey.arrowRight: Inp.right,
    LogicalKeyboardKey.keyW: Inp.up,
    LogicalKeyboardKey.arrowUp: Inp.up,
    LogicalKeyboardKey.keyS: Inp.down,
    LogicalKeyboardKey.arrowDown: Inp.down,
    LogicalKeyboardKey.keyJ: Inp.light,
    LogicalKeyboardKey.keyK: Inp.heavy,
    LogicalKeyboardKey.keyL: Inp.special,
    LogicalKeyboardKey.space: Inp.roll,
    LogicalKeyboardKey.keyI: Inp.superBtn,
  };
}

enum _Btn { light, heavy, special, roll, superBtn }

/// The touch deck: a floating stick anywhere on the left half and five
/// buttons on the right, all through ONE multi-touch [Listener], so pressing
/// Light and Heavy together (a throw) or holding a direction while tapping
/// works the way thumbs expect. No ink, no ripples: pressed state is drawn.
class FightTouchControls extends StatefulWidget {
  const FightTouchControls({
    super.key,
    required this.input,
    required this.superReady,
    this.overlay = false,
    this.onPress,
  });

  final FightInput input;

  /// Lights up the Super button (2 bars of meter).
  final ValueListenable<bool> superReady;

  /// True when drawn over the stage (landscape): lighter, translucent.
  final bool overlay;

  /// A button went down: for a haptic tick.
  final VoidCallback? onPress;

  @override
  State<FightTouchControls> createState() => _FightTouchControlsState();
}

class _FightTouchControlsState extends State<FightTouchControls> {
  // stick
  int? _stickPointer;
  Offset? _stickOrigin, _stickPos;
  // buttons
  final Map<int, _Btn> _btnPointers = {};
  final Map<_Btn, Rect> _btnRects = {};

  static const double _dead = 14, _radius = 54;

  int get _btnMask {
    var m = 0;
    for (final b in _btnPointers.values) {
      m |= switch (b) {
        _Btn.light => Inp.light,
        _Btn.heavy => Inp.heavy,
        _Btn.special => Inp.special,
        _Btn.roll => Inp.roll,
        _Btn.superBtn => Inp.superBtn,
      };
    }
    return m;
  }

  int get _stickMask {
    final o = _stickOrigin, p = _stickPos;
    if (o == null || p == null) return 0;
    final d = p - o;
    if (d.distance < _dead) return 0;
    // 8 sectors of 45 degrees.
    final a = math.atan2(-d.dy, d.dx);
    final sector = ((a + math.pi * 2 + math.pi / 8) % (math.pi * 2)) ~/ (math.pi / 4);
    return const [
      Inp.right, Inp.right | Inp.up, Inp.up, Inp.left | Inp.up,
      Inp.left, Inp.left | Inp.down, Inp.down, Inp.right | Inp.down,
    ][sector];
  }

  void _sync() {
    widget.input.touch = _stickMask | _btnMask;
    setState(() {});
  }

  _Btn? _hitButton(Offset p) {
    _Btn? best;
    var bestD = double.infinity;
    for (final e in _btnRects.entries) {
      final r = e.value.inflate(10);
      if (!r.contains(p)) continue;
      final d = (r.center - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = e.key;
      }
    }
    return best;
  }

  void _down(PointerDownEvent e, Size size) {
    final p = e.localPosition;
    if (p.dx < size.width * 0.45) {
      if (_stickPointer != null) return;
      _stickPointer = e.pointer;
      _stickOrigin = p;
      _stickPos = p;
    } else {
      final b = _hitButton(p);
      if (b == null) return;
      if (b == _Btn.superBtn && !widget.superReady.value) return;
      _btnPointers[e.pointer] = b;
      widget.onPress?.call();
    }
    _sync();
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer == _stickPointer) {
      final o = _stickOrigin!;
      var d = e.localPosition - o;
      // Drag past the rim and the base follows the thumb, so the stick never
      // "runs out" and reversing direction is always a short move.
      if (d.distance > _radius) {
        _stickOrigin = e.localPosition - d / d.distance * _radius;
        d = e.localPosition - _stickOrigin!;
      }
      _stickPos = e.localPosition;
      _sync();
    } else if (_btnPointers.containsKey(e.pointer)) {
      // Sliding a thumb onto a neighbouring button switches to it.
      final b = _hitButton(e.localPosition);
      if (b != null && b != _btnPointers[e.pointer] && (b != _Btn.superBtn || widget.superReady.value)) {
        _btnPointers[e.pointer] = b;
        widget.onPress?.call();
        _sync();
      }
    }
  }

  void _up(int pointer) {
    if (pointer == _stickPointer) {
      _stickPointer = null;
      _stickOrigin = null;
      _stickPos = null;
    }
    _btnPointers.remove(pointer);
    _sync();
  }

  @override
  void dispose() {
    widget.input.touch = 0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        _layout(size);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e, size),
          onPointerMove: _move,
          onPointerUp: (e) => _up(e.pointer),
          onPointerCancel: (e) => _up(e.pointer),
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.superReady,
            builder: (context, ready, _) => CustomPaint(
              size: size,
              painter: _DeckPainter(
                overlay: widget.overlay,
                origin: _stickOrigin,
                knob: _stickPos,
                radius: _radius,
                rects: _btnRects,
                pressed: _btnPointers.values.toSet(),
                superReady: ready,
              ),
              child: Stack(
                children: [
                  for (final e in _btnRects.entries)
                    Positioned.fromRect(
                      rect: e.value,
                      child: IgnorePointer(
                        child: Icon(
                          _icon(e.key),
                          size: e.value.width * 0.4,
                          color: (e.key == _Btn.superBtn && !ready) ? const Color(0x55ffffff) : const Color(0xffffffff),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static IconData _icon(_Btn b) => switch (b) {
    _Btn.light => CupertinoIcons.hand_raised_fill,
    _Btn.heavy => CupertinoIcons.burst_fill,
    _Btn.special => CupertinoIcons.sparkles,
    _Btn.roll => CupertinoIcons.arrow_2_circlepath,
    _Btn.superBtn => CupertinoIcons.bolt_fill,
  };

  /// Buttons in an arc around the right thumb's resting point: the three
  /// attacks where the thumb lands, roll below, super above, out of the way
  /// of accidental presses.
  void _layout(Size size) {
    final unit = math.min(size.height / 3.1, size.width / 6.4).clamp(46.0, 78.0);
    final cx = size.width - unit * 1.75, cy = size.height - unit * 1.45;
    Rect at(double dx, double dy, double s) => Rect.fromCenter(center: Offset(cx + dx * unit, cy + dy * unit), width: unit * s, height: unit * s);
    _btnRects
      ..[_Btn.light] = at(-1.05, 0.25, 1.0)
      ..[_Btn.heavy] = at(0.05, -0.3, 1.1)
      ..[_Btn.special] = at(1.0, 0.3, 1.0)
      ..[_Btn.roll] = at(-0.05, 0.95, 0.8)
      ..[_Btn.superBtn] = at(0.95, -1.2, 0.85);
  }
}

class _DeckPainter extends CustomPainter {
  _DeckPainter({
    required this.overlay,
    required this.origin,
    required this.knob,
    required this.radius,
    required this.rects,
    required this.pressed,
    required this.superReady,
  });

  final bool overlay;
  final Offset? origin, knob;
  final double radius;
  final Map<_Btn, Rect> rects;
  final Set<_Btn> pressed;
  final bool superReady;

  static const _tints = {
    _Btn.light: Color(0xff3fd2c7),
    _Btn.heavy: Color(0xffff8a3d),
    _Btn.special: Color(0xffb38bff),
    _Btn.roll: Color(0xff8d86a8),
    _Btn.superBtn: Color(0xffffd23a),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final a = overlay ? 0.55 : 1.0;
    // Stick: a resting hint when untouched, the live base + knob when held.
    final base = origin ?? Offset(size.width * 0.2, size.height * 0.62);
    final k = knob ?? base;
    canvas.drawCircle(base, radius, Paint()..color = Color.fromRGBO(255, 255, 255, 0.07 * a));
    canvas.drawCircle(base, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.fromRGBO(255, 255, 255, (origin == null ? 0.18 : 0.35) * a));
    var d = k - base;
    if (d.distance > radius) d = d / d.distance * radius;
    canvas.drawCircle(base + d, radius * 0.46, Paint()..color = Color.fromRGBO(255, 255, 255, (origin == null ? 0.2 : 0.6) * a));

    for (final e in rects.entries) {
      final r = e.value;
      final on = pressed.contains(e.key);
      final tint = _tints[e.key]!;
      final dim = e.key == _Btn.superBtn && !superReady;
      final c = r.center;
      final rad = r.width / 2 * (on ? 0.92 : 1);
      if (e.key == _Btn.superBtn && superReady) {
        canvas.drawCircle(c, rad * 1.25, Paint()
          ..color = tint.withValues(alpha: 0.35 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      }
      canvas.drawCircle(c, rad, Paint()..color = tint.withValues(alpha: (dim ? 0.12 : (on ? 0.95 : 0.42)) * a));
      canvas.drawCircle(c, rad, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = tint.withValues(alpha: (dim ? 0.25 : 0.9) * a));
    }
  }

  @override
  bool shouldRepaint(_DeckPainter o) => true;
}
