import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/push/alert_burst.dart';

void main() {
  final t0 = DateTime(2026, 10, 29, 12);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  test('a burst alerts once, then lands quietly', () {
    final b = AlertBurst();
    expect(b.shouldAlert('r', at(0)), isTrue);
    expect(b.shouldAlert('r', at(5)), isFalse);
    expect(b.shouldAlert('r', at(20)), isFalse);
  });

  test('a pause longer than the gap starts a new burst', () {
    final b = AlertBurst();
    b.shouldAlert('r', at(0));
    expect(b.shouldAlert('r', at(46)), isTrue);
  });

  // The gap slides with every message, so without the reminder a room that
  // never pauses for 45s would go quiet for good.
  test('a burst that keeps going still alerts every few minutes', () {
    final b = AlertBurst();
    final heard = <int>[];
    for (var s = 0; s <= 400; s += 10) {
      if (b.shouldAlert('r', at(s))) heard.add(s);
    }
    expect(heard, [0, 180, 360]);
  });

  test('rooms are independent', () {
    final b = AlertBurst();
    b.shouldAlert('a', at(0));
    expect(b.shouldAlert('b', at(1)), isTrue);
  });

  test('a mention always alerts', () {
    final b = AlertBurst();
    b.shouldAlert('r', at(0));
    expect(b.shouldAlert('r', at(2), mention: true), isTrue);
  });
}
