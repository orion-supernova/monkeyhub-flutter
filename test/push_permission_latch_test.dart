import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/push/permission_latch.dart';

/// The notification-permission ask is one-shot, and that is not tidiness.
///
/// On Android, requesting a permission the user has refused twice returns
/// instantly with no dialog while still pausing and resuming the activity —
/// and the resume is what schedules the foreground sync that asks again. The
/// result is a permanent resume/inactive loop burning a token write and a
/// query on every flip. These tests pin the four rules that break it.
void main() {
  ({
    PermissionLatch latch,
    List<String> calls,
  }) build({
    String? status = 'notDetermined',
    bool foreground = true,
    Object? throwOnStatus,
  }) {
    final calls = <String>[];
    final latch = PermissionLatch(
      readStatus: () async {
        calls.add('status');
        if (throwOnStatus != null) throw throwOnStatus;
        return status;
      },
      request: () async => calls.add('request'),
      isForeground: () => foreground,
    );
    return (latch: latch, calls: calls);
  }

  test('asks exactly once, however many times it is invoked', () async {
    final t = build();
    await t.latch.maybeAsk();
    await t.latch.maybeAsk();
    await t.latch.maybeAsk();
    expect(t.calls, ['status', 'request']);
  });

  test('does not ask — or spend the one ask — while backgrounded', () async {
    final t = build(foreground: false);
    await t.latch.maybeAsk();
    expect(t.calls, isEmpty);
    expect(t.latch.settled, isFalse,
        reason: 'a headless launch must not burn the single ask');
  });

  test('never asks again after a denial', () async {
    // The exact case that arms the loop: the OS will not show a sheet, but
    // requesting still churns the activity lifecycle.
    final t = build(status: 'denied');
    await t.latch.maybeAsk();
    await t.latch.maybeAsk();
    expect(t.calls, ['status']);
  });

  test('does not ask when already granted', () async {
    final t = build(status: 'granted');
    await t.latch.maybeAsk();
    expect(t.calls, ['status']);
  });

  test('treats provisional authorization as answered', () async {
    final t = build(status: 'provisional');
    await t.latch.maybeAsk();
    expect(t.calls, ['status']);
  });

  test('a channel failure unlatches, so a later foreground can retry',
      () async {
    // Distinct from a denial: nothing was decided, so staying silent forever
    // after one transient failure is the worse outcome.
    final t = build(throwOnStatus: StateError('channel down'));
    await t.latch.maybeAsk();
    expect(t.calls, ['status']);
    expect(t.latch.settled, isFalse);
  });

  test('concurrent callers cannot both reach the prompt', () async {
    // The prompt itself pauses and resumes the app, so the second caller is
    // not hypothetical — it is the resume handler.
    final t = build();
    await Future.wait([
      t.latch.maybeAsk(),
      t.latch.maybeAsk(),
      t.latch.maybeAsk(),
    ]);
    expect(t.calls.where((c) => c == 'request').length, 1);
  });
}
