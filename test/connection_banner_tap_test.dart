import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/connection_health.dart';
import 'package:monkeyhub/keyboard/focusable_tap.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/connection_banner.dart';

/// FocusableTap adds keyboard focus only — it registers NO gesture recognizer,
/// so anything wrapped in it must ALSO carry its own GestureDetector.onTap to
/// be tappable at all. That has shipped broken once already (see the header of
/// call_controls_tap_test.dart), and it went wrong here a second time: the
/// banner's duplicate binding looks redundant and is not.
///
/// This is the highest-stakes tap in the app to get wrong. "can't reach server
/// · tap to retry" is shown precisely when nothing else is working, and a dead
/// tap there is invisible in review — the widget still builds, still reads
/// right, still passes semantics.

/// Never actually probes; the loop is not what these tests are about.
class _StubProbe implements ConnectionProbe {
  final _ctrl = StreamController<bool>.broadcast();
  int retries = 0;

  @override
  bool get isConnected => true;
  @override
  Stream<bool> get connectionState => _ctrl.stream;
  @override
  Future<bool> probeConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    retries++;
    return false;
  }

  @override
  Future<bool> reconnect() async => false;

  Future<void> close() => _ctrl.close();
}

void main() {
  late _StubProbe probe;
  late ConnectionHealth health;

  Future<void> pumpStalled(WidgetTester tester) async {
    probe = _StubProbe();
    health = ConnectionHealth(
      backend: probe,
      onReconnected: () async {},
      isActive: () => true,
      graceDelay: const Duration(milliseconds: 1),
      initialGraceDelay: const Duration(milliseconds: 1),
      stalledAfter: const Duration(milliseconds: 2),
      firstProbeTimeout: const Duration(milliseconds: 1),
      probeTimeout: const Duration(milliseconds: 1),
      backoff: const [Duration(seconds: 30)],
      minLoopInterval: const Duration(milliseconds: 1),
      watchConnectivity: false,
    )..start();

    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          home: Scaffold(body: ConnectionBanner(health: health)),
        ),
      ),
    );
    // Drive it to `stalled`, which is the only phase that offers a retry.
    // Two failed round-trips is the frozen-socket detector.
    health.noteRoundTrip(ok: false);
    health.noteRoundTrip(ok: false);
    for (var i = 0; i < 20 && health.phase != ConnectionPhase.stalled; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(health.phase, ConnectionPhase.stalled);
    // Let the AnimatedSize finish growing. Until it has, the strip is clipped
    // to a fraction of its height and a tap at the label's centre lands on
    // nothing — which looks exactly like a missing handler.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the stalled banner responds to a tap', (tester) async {
    await pumpStalled(tester);
    final before = probe.retries;

    await tester.tap(find.text("can't reach server · tap to retry"));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      probe.retries,
      greaterThan(before),
      reason:
          'FocusableTap alone binds Enter/Space and nothing else, so the '
          'banner is dead to touch, mouse and VoiceOver without its own '
          'GestureDetector.onTap',
    );

    health.dispose();
    await probe.close();
  });

  testWidgets('the whole strip is tappable, not just the label', (
    tester,
  ) async {
    await pumpStalled(tester);
    final before = probe.retries;

    // The padding either side of the label is most of the target. Without
    // HitTestBehavior.opaque those gaps fall through to whatever is behind.
    final strip = tester.getRect(find.byType(ConnectionBanner));
    await tester.tapAt(Offset(strip.right - 6, strip.center.dy));
    await tester.pump(const Duration(milliseconds: 50));

    expect(probe.retries, greaterThan(before));

    health.dispose();
    await probe.close();
  });

  // The canary for the assumption the two tests above rest on. If FocusableTap
  // ever grows a gesture recognizer this fails, and the duplicate binding in
  // ConnectionBanner (and in every other tappable in the app) can go.
  testWidgets('FocusableTap on its own is not tappable', (tester) async {
    var outer = 0;
    var inner = 0;
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: FocusableTap(
                onTap: () => outer++,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => inner++,
                  child: const SizedBox(
                    width: 200,
                    height: 60,
                    child: Text('hit me'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('hit me'));
    await tester.pump();

    expect(outer, 0, reason: 'FocusableTap binds Enter/Space, not pointers');
    expect(inner, 1, reason: 'the inner detector is what makes it tappable');
  });
}
