import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/signaling_status.dart';

void main() {
  late DateTime now;
  late SignalingStatus status;
  final t0 = DateTime.utc(2026, 10, 18, 12);

  setUp(() {
    now = t0;
    status = SignalingStatus(now: () => now);
  });

  void at(int s) => now = t0.add(Duration(seconds: s));
  Duration secs(int s) => Duration(seconds: s);

  test('counts only the part of an outage inside the window', () {
    at(10);
    status.markDown();
    at(20);
    status.markUp();
    at(40);
    status.markDown();
    at(45);
    status.markUp();

    expect(status.downtimeBetween(t0, t0.add(secs(60))), secs(15));
    // Clipped at both ends.
    expect(status.downtimeBetween(t0.add(secs(15)), t0.add(secs(42))), secs(7));
    expect(status.downtimeBetween(t0.add(secs(21)), t0.add(secs(39))),
        Duration.zero);
  });

  test('an outage still in progress counts up to now', () {
    at(5);
    status.markDown();
    expect(status.isDown, isTrue);
    expect(status.downtimeBetween(t0, t0.add(secs(12))), secs(7));
  });

  test('edges are idempotent and counted', () {
    var notified = 0;
    status.addListener(() => notified++);
    status.markUp(); // nothing to close
    status.markDown();
    status.markDown(); // already down
    at(3);
    status.markUp();
    status.noteNetworkChanged();
    expect(status.upEdges, 1);
    expect(status.networkEpoch, 1);
    expect(notified, 3);
  });

  test('an empty or inverted window is zero', () {
    status.markDown();
    expect(status.downtimeBetween(t0, t0), Duration.zero);
    expect(status.downtimeBetween(t0.add(secs(5)), t0), Duration.zero);
  });
}
