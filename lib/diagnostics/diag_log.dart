import 'package:flutter/foundation.dart';

import 'diag_buffer.dart';
import 'diag_event.dart';
import 'redactor.dart';

/// The only surface capture sites touch.
///
/// Every method is a no-op returning immediately when [enabled] is false, so an
/// ordinary user pays one static bool read at each of the ~20 call sites and
/// nothing else. That cheapness is what lets the calls sit in hot paths —
/// `didChangeMetrics`, the frame callback, every Convex round trip — without
/// needing their own guards.
class DiagLog {
  const DiagLog._();

  /// Off until [DiagGate] says otherwise. Never flipped on by a debug build:
  /// the whole point is that this runs on a release build on somebody else's
  /// phone.
  static bool enabled = false;

  /// The `debugPrint` that existed before we replaced it.
  ///
  /// Load-bearing, not a convenience. This class must be able to report its own
  /// failures, and doing that through the overridden `debugPrint` would call
  /// back into capture, which would fail again, which would report again. Every
  /// internal message goes here instead.
  static DebugPrintCallback? rawPrint;

  /// Reentrancy latch for the `debugPrint` override — capture code that itself
  /// prints must not be captured.
  static bool _inCapture = false;

  /// The current route, kept up to date by `route_tracker.dart`.
  static String? currentScreen;

  static DiagBuffer get _buf => DiagBuffer.instance;

  /// Convex calls whose own traffic must never be logged.
  ///
  /// The gate check runs through the same client as everything else, so without
  /// this every allowlist refresh would log itself — and on a device where the
  /// socket is flapping it would do so repeatedly.
  static bool isSelfTraffic(String name) => name.startsWith('diagnostics:');

  static void add({
    required DiagCat cat,
    required DiagSev sev,
    required String event,
    String? name,
    String? corrId,
    int? durationMs,
    bool? ok,
    String? detail,
    String? body,
  }) {
    if (!enabled) return;
    _buf.add(
      cat: cat,
      sev: sev,
      event: event,
      name: name,
      corrId: corrId,
      durationMs: durationMs,
      ok: ok,
      detail: detail,
      body: body,
      screen: currentScreen,
    );
  }

  // ───────── API ─────────

  /// Records the start of a Convex call and returns its sequence number, which
  /// the caller hands back to [apiEnd] / [apiError] as the correlation id.
  /// Returns null when disabled, which callers treat as "nothing to correlate".
  static int? apiStart(String kind, String name, Map<String, dynamic> args) {
    if (!enabled || isSelfTraffic(name)) return null;
    final seq = _buf.nextSeq();
    _buf.add(
      seq: seq,
      cat: DiagCat.api,
      sev: DiagSev.debug,
      event: kind, // 'query' | 'mutation' | 'action'
      name: name,
      detail: Redactor.policyFor(name) == ArgPolicy.drop
          ? '${args.length} args'
          : null,
      body: Redactor.args(name, args),
      screen: currentScreen,
    );
    return seq;
  }

  static void apiEnd(int? corr, String name, int ms, Object? result) {
    if (!enabled || corr == null) return;
    _buf.add(
      cat: DiagCat.api,
      sev: ms > 3000 ? DiagSev.warn : DiagSev.debug,
      event: 'result',
      name: name,
      corrId: '$corr',
      durationMs: ms,
      ok: true,
      detail: _describe(result),
      body: Redactor.result(name, result),
      screen: currentScreen,
    );
  }

  static void apiError(int? corr, String name, int ms, Object error) {
    if (!enabled) return;
    _buf.add(
      cat: DiagCat.api,
      sev: DiagSev.error,
      event: 'error',
      name: name,
      corrId: corr == null ? null : '$corr',
      durationMs: ms,
      ok: false,
      detail: Redactor.text(error.toString()),
      screen: currentScreen,
    );
  }

  // ───────── subscriptions ─────────

  static int? subOpen(String name, Map<String, dynamic> args) {
    if (!enabled || isSelfTraffic(name)) return null;
    final seq = _buf.nextSeq();
    _buf.add(
      seq: seq,
      cat: DiagCat.subscription,
      sev: DiagSev.info,
      event: 'open',
      name: name,
      body: Redactor.args(name, args),
      screen: currentScreen,
    );
    return seq;
  }

  /// Subscription payloads are deliberately NOT recorded — only their shape and
  /// timing. Fifteen live subscriptions delivering full documents would bury
  /// every other event in the timeline, and for this bug the useful fact is
  /// that an update arrived at all, not what was in it.
  static void subUpdate(int? corr, String name, Object? data) {
    if (!enabled || corr == null) return;
    _buf.add(
      cat: DiagCat.subscription,
      sev: DiagSev.trace,
      event: 'update',
      name: name,
      corrId: '$corr',
      detail: _describe(data),
      screen: currentScreen,
    );
  }

  static void subError(int? corr, String name, Object error) {
    if (!enabled) return;
    _buf.add(
      cat: DiagCat.subscription,
      sev: DiagSev.error,
      event: 'error',
      name: name,
      corrId: corr == null ? null : '$corr',
      ok: false,
      detail: Redactor.text(error.toString()),
      screen: currentScreen,
    );
  }

  // ───────── console capture ─────────

  /// Captures one line that went through `debugPrint`.
  ///
  /// The app already has ~192 `debugPrint` calls carrying the exact context a
  /// triager wants — `ConvexBackend.reconnect: …`, `ConnectionHealth.…`,
  /// `_asyncSessionAttach error: …`. Overriding the global picks up every one
  /// of them with no edits to any of those files.
  ///
  /// The latch is what stops this eating itself: writing an event can fail, a
  /// failure gets reported, and if that report went through `debugPrint` we
  /// would be back in here with the same broken state, forever.
  static void captureLine(String line) {
    if (!enabled || _inCapture) return;
    _inCapture = true;
    try {
      // Severity inferred from the text because the call sites have no level.
      // Crude, and still the difference between a readable filter and one
      // where everything is 'info'.
      final lower = line.toLowerCase();
      final sev =
          lower.contains('failed') ||
              lower.contains('error') ||
              lower.contains('exception')
          ? DiagSev.warn
          : DiagSev.debug;
      _buf.add(
        cat: DiagCat.log,
        sev: sev,
        event: 'print',
        detail: Redactor.text(line),
        screen: currentScreen,
      );
    } catch (_) {
      // Never let diagnostics break the thing it is diagnosing.
    } finally {
      _inCapture = false;
    }
  }

  // ───────── convenience wrappers ─────────

  static void lifecycle(String detail) => add(
    cat: DiagCat.lifecycle,
    sev: DiagSev.info,
    event: 'state',
    detail: detail,
  );

  static void connection(String event, String detail, {DiagSev? sev}) => add(
    cat: DiagCat.connection,
    sev: sev ?? DiagSev.info,
    event: event,
    detail: detail,
  );

  static void error(
    String event,
    Object err, {
    StackTrace? stack,
    String? name,
  }) {
    if (!enabled) return;
    _buf.add(
      cat: DiagCat.error,
      sev: DiagSev.error,
      event: event,
      name: name ?? err.runtimeType.toString(),
      detail: Redactor.text(err.toString()),
      // First frames only: a full Flutter stack is thousands of characters and
      // the answer is essentially always near the top.
      body: stack == null ? null : Redactor.text(_topFrames(stack, 12)),
      screen: currentScreen,
    );
  }

  /// Size-only description of a payload, safe for any policy.
  static String? _describe(Object? v) {
    if (v == null) return null;
    if (v is List) return '${v.length} items';
    if (v is Map) return '${v.length} keys';
    if (v is String) return '${v.length} chars';
    return null;
  }

  static String _topFrames(StackTrace stack, int n) {
    final lines = stack.toString().split('\n');
    return lines.take(n).join('\n');
  }
}
