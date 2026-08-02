import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/subscription_registry.dart';

/// Stands in for the transport. Records every bind and cancel so tests can
/// assert on the *sequence*, not just counts — "rebind cancelled nothing" is a
/// different claim from "rebind cancelled the right thing".
class FakeTransport {
  final List<String> binds = [];
  final List<Object> cancels = [];

  /// When non-null, the next bind parks on this instead of completing.
  Completer<void>? gate;

  /// When non-null, the next bind throws this.
  Object? failWith;

  int _next = 0;

  Future<Object> bind(
    String name,
    Map<String, dynamic> args,
    void Function(dynamic) onData,
    void Function(Object)? onError,
  ) async {
    binds.add(name);
    final g = gate;
    if (g != null) {
      gate = null;
      await g.future;
    }
    final f = failWith;
    if (f != null) {
      failWith = null;
      throw f;
    }
    return 'h${_next++}';
  }

  void cancel(Object handle) => cancels.add(handle);
}

SubscriptionRegistry _registryFor(FakeTransport t) =>
    SubscriptionRegistry(bind: t.bind, cancel: t.cancel);

void main() {
  group('SubscriptionRegistry', () {
    test(
      'rebindAll re-binds every live entry and cancels no old handle',
      () async {
        final t = FakeTransport();
        final r = _registryFor(t);
        for (final n in ['rooms', 'friends', 'typing']) {
          await r.add(n, const {}, onData: (_) {});
        }
        t.binds.clear();

        await r.rebindAll(1);

        expect(t.binds, ['rooms', 'friends', 'typing']);
        // The old handles' peer is gone after a transport rebuild. Cancelling
        // them is a no-op at best and used to panic across FFI.
        expect(t.cancels, isEmpty);
        expect(r.liveCount, 3);
      },
    );

    test('rebindAll at the same generation is a no-op', () async {
      final t = FakeTransport();
      final r = _registryFor(t);
      await r.add('rooms', const {}, onData: (_) {});
      t.binds.clear();

      await r.rebindAll(1);
      await r.rebindAll(1);

      expect(t.binds, ['rooms']);
    });

    test(
      'a cancel during a rebind cancels the fresh handle and drops the entry',
      () async {
        final t = FakeTransport();
        final r = _registryFor(t);
        final sub = await r.add('rooms', const {}, onData: (_) {});
        final firstHandle = t.cancels.length; // 0 — nothing cancelled yet

        final gate = Completer<void>();
        t.gate = gate;
        final rebind = r.rebindAll(1);
        // The bind is parked. The caller gives up on the subscription now.
        sub.cancel();
        gate.complete();
        await rebind;

        expect(r.liveCount, 0);
        expect(firstHandle, 0);
        // Both the handle it held and the one the rebind produced.
        expect(t.cancels, ['h0', 'h1']);
      },
    );

    test(
      'a subscribe that lands after a rebuild is re-bound exactly once',
      () async {
        final t = FakeTransport();
        final r = _registryFor(t);

        final gate = Completer<void>();
        t.gate = gate;
        final adding = r.add('rooms', const {}, onData: (_) {});
        // The rebuild happens while that subscribe is still in flight. The entry
        // is already in the registry, so the rebind picks it up.
        final rebind = r.rebindAll(1);
        gate.complete();
        await adding;
        await rebind;

        expect(t.binds, ['rooms', 'rooms']);
        // The stale one loses and is cleaned up; exactly one handle survives.
        expect(t.cancels.length, 1);
        expect(r.liveCount, 1);
      },
    );

    test(
      'a failing bind reports onError and stays eligible for the next rebind',
      () async {
        final t = FakeTransport();
        final r = _registryFor(t);
        Object? reported;
        t.failWith = StateError('socket down');
        await r.add(
          'rooms',
          const {},
          onData: (_) {},
          onError: (e) => reported = e,
        );

        expect(reported, isA<StateError>());
        expect(r.liveCount, 1);

        t.binds.clear();
        await r.rebindAll(1);
        expect(t.binds, ['rooms']);
      },
    );

    test('cancel is idempotent and never touches a stale handle', () async {
      final t = FakeTransport();
      final r = _registryFor(t);
      final sub = await r.add('rooms', const {}, onData: (_) {});

      await r.rebindAll(1);
      sub.cancel();
      sub.cancel();
      sub.cancel();

      // Only the handle from the most recent bind, and only once.
      expect(t.cancels, ['h1']);
      expect(r.liveCount, 0);
    });

    // A subscribe issued while the socket is down does not always queue — the
    // web client throws outright and erases the record it would otherwise have
    // replayed. Nothing else in the system can heal that: the transport has
    // nothing to replay, and `rebindAll` only runs after a forced rebuild,
    // which on web never happens. So `rebindFailed` is the only thing standing
    // between a slow handshake at sign-in and a room list that never updates
    // again — behind a UI that looks perfectly healthy.
    test('rebindFailed re-binds an entry whose original bind threw', () async {
      final t = FakeTransport();
      final r = _registryFor(t);
      t.failWith = StateError('WebSocket not connected');
      Object? reported;
      await r.add(
        'rooms',
        const {},
        onData: (_) {},
        onError: (e) => reported = e,
      );
      expect(reported, isA<StateError>());
      t.binds.clear();

      await r.rebindFailed();

      expect(t.binds, ['rooms']);
      expect(r.liveCount, 1);
    });

    test('rebindFailed leaves healthy entries alone', () async {
      final t = FakeTransport();
      final r = _registryFor(t);
      await r.add('rooms', const {}, onData: (_) {});
      t.failWith = StateError('down');
      await r.add('friends', const {}, onData: (_) {});
      t.binds.clear();

      await r.rebindFailed();

      expect(t.binds, [
        'friends',
      ], reason: 'rebinding a live one would orphan its server-side copy');
      expect(t.cancels, isEmpty);
    });

    test('rebindFailed is a no-op when everything is bound', () async {
      final t = FakeTransport();
      final r = _registryFor(t);
      await r.add('rooms', const {}, onData: (_) {});
      t.binds.clear();

      await r.rebindFailed();

      expect(t.binds, isEmpty);
    });

    test('a cancelled entry is skipped by later rebinds', () async {
      final t = FakeTransport();
      final r = _registryFor(t);
      final a = await r.add('rooms', const {}, onData: (_) {});
      await r.add('friends', const {}, onData: (_) {});
      a.cancel();
      t.binds.clear();

      await r.rebindAll(1);

      expect(t.binds, ['friends']);
    });
  });
}
