import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart' show GamepadAxis, GamepadButton;
import 'package:monkeyhub/fight/core/input.dart';
import 'package:monkeyhub/fight/view/fight_gamepad.dart';

void main() {
  late GamepadMapper m;
  setUp(() => m = GamepadMapper());

  void press(GamepadButton b, [String pad = 'p1']) => m.button(pad, b, 1);
  void release(GamepadButton b, [String pad = 'p1']) => m.button(pad, b, 0);
  void stick(double x, double y, [String pad = 'p1']) {
    m.axis(pad, GamepadAxis.leftStickX, x);
    m.axis(pad, GamepadAxis.leftStickY, y);
  }

  test('face buttons and shoulders map to attacks', () {
    const want = {
      GamepadButton.a: Inp.light,
      GamepadButton.x: Inp.heavy,
      GamepadButton.b: Inp.special,
      GamepadButton.leftBumper: Inp.special,
      GamepadButton.y: Inp.superBtn,
      GamepadButton.rightBumper: Inp.roll,
    };
    want.forEach((b, bit) {
      press(b);
      expect(m.mask, bit, reason: '$b');
      release(b);
      expect(m.mask, 0, reason: '$b release');
    });
  });

  test('buttons are held independently', () {
    press(GamepadButton.a);
    press(GamepadButton.x);
    expect(m.mask, Inp.light | Inp.heavy);
    release(GamepadButton.a);
    expect(m.mask, Inp.heavy);
  });

  test('d-pad maps to directions', () {
    press(GamepadButton.dpadLeft);
    press(GamepadButton.dpadUp);
    expect(m.mask, Inp.left | Inp.up);
  });

  test('stick deadzone', () {
    stick(0.39, 0);
    expect(m.mask, 0);
    stick(0.41, 0);
    expect(m.mask, Inp.right);
    stick(0.3, 0.3); // magnitude 0.42, radial
    expect(m.mask, Inp.right | Inp.up);
    stick(0.2, 0.2); // 0.28
    expect(m.mask, 0);
  });

  test('stick is 8-way, y up is +1', () {
    final cases = {
      (1.0, 0.0): Inp.right,
      (1.0, 1.0): Inp.right | Inp.up,
      (0.0, 1.0): Inp.up,
      (-1.0, 1.0): Inp.left | Inp.up,
      (-1.0, 0.0): Inp.left,
      (-1.0, -1.0): Inp.left | Inp.down,
      (0.0, -1.0): Inp.down,
      (1.0, -1.0): Inp.right | Inp.down,
      (1.0, 0.2): Inp.right, // within 22.5 degrees of east
      (0.2, 1.0): Inp.up,
    };
    cases.forEach((v, bits) {
      stick(v.$1, v.$2);
      expect(m.mask, bits, reason: '$v');
    });
  });

  test('stick and d-pad merge with buttons', () {
    stick(-1, 0);
    press(GamepadButton.dpadUp);
    press(GamepadButton.a);
    expect(m.mask, Inp.left | Inp.up | Inp.light);
  });

  test('unmapped inputs and the right stick do nothing', () {
    press(GamepadButton.back);
    press(GamepadButton.leftStick);
    expect(m.button('p1', GamepadButton.leftTrigger, 1), isFalse);
    m.axis('p1', GamepadAxis.rightStickX, 1);
    expect(m.mask, 0);
  });

  test('start reports a press without being held state', () {
    expect(m.button('p1', GamepadButton.start, 1), isTrue);
    expect(m.button('p1', GamepadButton.start, 0), isFalse);
    expect(m.mask, 0);
  });

  test('activity: drift is ignored, a push or press counts', () {
    expect(m.axis('p1', GamepadAxis.leftStickX, 0.1), isFalse);
    expect(m.axis('p1', GamepadAxis.leftStickX, 0.9), isTrue);
    expect(m.button('p1', GamepadButton.a, 1), isTrue);
    expect(m.button('p1', GamepadButton.a, 0), isFalse);
  });

  test('disconnect releases everything that pad held, only that pad', () {
    press(GamepadButton.a);
    stick(1, 0);
    press(GamepadButton.x, 'p2');
    m.disconnect('p1');
    expect(m.mask, Inp.heavy);
    m.disconnect('p2');
    expect(m.mask, 0);
    expect(m.isEmpty, isTrue);
  });
}
