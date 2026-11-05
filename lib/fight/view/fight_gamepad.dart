import 'dart:math' as math;

import 'package:gamepads/gamepads.dart' show GamepadAxis, GamepadButton;

import '../core/input.dart';

/// Controller state to engine bitmask, with no plugin in sight so it can be
/// tested: the screen feeds it the gamepads package's normalized events.
///
/// Held state is per pad and per button, so two controllers (or a stick plus
/// the D-pad) merge instead of fighting, and [disconnect] releases one pad.
class GamepadMapper {
  /// Radial stick deadzone; past it the angle picks one of 8 directions.
  static const double deadzone = 0.4;

  final Map<String, _Pad> _pads = {};

  /// Standard layout. Names are the package's normalized ones: A/Cross is
  /// [GamepadButton.a] on every platform, and the package turns each OS's raw
  /// keys (GCController SF Symbols, Android KEYCODE_*, Windows GameInput, Linux
  /// SDL database) into them.
  static const Map<GamepadButton, int> buttonBits = {
    GamepadButton.a: Inp.light,
    GamepadButton.x: Inp.heavy,
    GamepadButton.b: Inp.special,
    GamepadButton.leftBumper: Inp.special,
    GamepadButton.y: Inp.superBtn,
    GamepadButton.rightBumper: Inp.roll,
    GamepadButton.dpadLeft: Inp.left,
    GamepadButton.dpadRight: Inp.right,
    GamepadButton.dpadUp: Inp.up,
    GamepadButton.dpadDown: Inp.down,
  };

  int get mask {
    var m = 0;
    for (final p in _pads.values) {
      m |= p.mask;
    }
    return m;
  }

  bool get isEmpty => _pads.isEmpty;

  /// Returns true when this is a press worth reacting to (any mapped button
  /// or Start going down).
  bool button(String pad, GamepadButton b, double value) {
    final down = value > 0.5;
    if (b == GamepadButton.start) return down;
    if (!buttonBits.containsKey(b)) return false;
    final p = _pads.putIfAbsent(pad, _Pad.new);
    down ? p.held.add(b) : p.held.remove(b);
    return down;
  }

  /// Returns true when the left stick is pushed past the deadzone, so a
  /// drifting stick at rest never counts as "the player is using a pad".
  bool axis(String pad, GamepadAxis a, double value) {
    final p = _pads.putIfAbsent(pad, _Pad.new);
    switch (a) {
      case GamepadAxis.leftStickX:
        p.x = value;
      case GamepadAxis.leftStickY:
        p.y = value;
      default:
        return false;
    }
    return p.stick != 0;
  }

  void disconnect(String pad) => _pads.remove(pad);

  void clear() => _pads.clear();
}

class _Pad {
  final Set<GamepadButton> held = {};
  double x = 0, y = 0; // y: up is +1

  int get stick {
    if (math.sqrt(x * x + y * y) < GamepadMapper.deadzone) return 0;
    // 8 sectors of 45 degrees, centred on the compass points.
    final a = math.atan2(y, x);
    final sector = ((a + math.pi * 2 + math.pi / 8) % (math.pi * 2)) ~/ (math.pi / 4);
    return const [
      Inp.right, Inp.right | Inp.up, Inp.up, Inp.left | Inp.up,
      Inp.left, Inp.left | Inp.down, Inp.down, Inp.right | Inp.down,
    ][sector];
  }

  int get mask {
    var m = stick;
    for (final b in held) {
      m |= GamepadMapper.buttonBits[b] ?? 0;
    }
    return m;
  }
}
