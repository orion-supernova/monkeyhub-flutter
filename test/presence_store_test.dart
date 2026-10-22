import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/presence_store.dart';

class _Sub {
  _Sub(this.ids, this.onData, this.onError);
  final List<String> ids;
  final void Function(dynamic) onData;
  final void Function(Object) onError;
  bool cancelled = false;
}

class _Harness {
  final subs = <_Sub>[];
  late final PresenceStore store = PresenceStore.forTest((ids, d, e) async {
    final s = _Sub(ids, d, e);
    subs.add(s);
    return () => s.cancelled = true;
  });
  _Sub get last => subs.last;
}

List<String> _ids(int n, [String p = 'u']) => [for (var i = 0; i < n; i++) '$p$i'];

void main() {
  test('adds coalesce into one subscription after 250 ms', () {
    fakeAsync((t) {
      final h = _Harness();
      h.store.lease(['a']);
      t.elapse(const Duration(milliseconds: 100));
      h.store.lease(['b', 'c']);
      t.elapse(const Duration(milliseconds: 100));
      expect(h.subs, isEmpty);
      t.elapse(const Duration(milliseconds: 100));
      expect(h.subs.length, 1);
      expect(h.last.ids, ['a', 'b', 'c']);
    });
  });

  test('an identical key never resubscribes', () {
    fakeAsync((t) {
      final h = _Harness();
      h.store.lease(['a', 'b']);
      t.elapse(const Duration(seconds: 1));
      h.store.lease(['b', 'a']);
      h.store.lease(['a']);
      t.elapse(const Duration(seconds: 5));
      expect(h.subs.length, 1);
      expect(h.last.cancelled, isFalse);
    });
  });

  test('removals wait 3 s, and a refcounted id survives one release', () {
    fakeAsync((t) {
      final h = _Harness();
      final l1 = h.store.lease(['a', 'b']);
      final l2 = h.store.lease(['a']);
      t.elapse(const Duration(seconds: 1));
      l1.release();
      l1.release(); // idempotent
      t.elapse(const Duration(milliseconds: 2900));
      expect(h.subs.length, 1);
      t.elapse(const Duration(milliseconds: 200));
      expect(h.subs.length, 2);
      expect(h.subs.first.cancelled, isTrue);
      expect(h.last.ids, ['a']);
      l2.release();
      t.elapse(const Duration(seconds: 4));
      expect(h.last.cancelled, isTrue);
      expect(h.store.subscribedIds, isEmpty);
    });
  });

  test('scrolling back within 3 s costs nothing', () {
    fakeAsync((t) {
      final h = _Harness();
      final l = h.store.lease(['a']);
      t.elapse(const Duration(seconds: 1));
      l.release();
      t.elapse(const Duration(seconds: 1));
      h.store.lease(['a']);
      t.elapse(const Duration(seconds: 10));
      expect(h.subs.length, 1);
      expect(h.last.cancelled, isFalse);
    });
  });

  test('an add keeps stale ids riding along while their removal waits', () {
    fakeAsync((t) {
      final h = _Harness();
      final l = h.store.lease(['a']);
      t.elapse(const Duration(seconds: 1));
      l.release();
      h.store.lease(['b']);
      t.elapse(const Duration(milliseconds: 300));
      expect(h.last.ids, ['a', 'b']);
      t.elapse(const Duration(seconds: 3));
      expect(h.last.ids, ['b']);
    });
  });

  test('caps at 100, most recently leased first', () {
    fakeAsync((t) {
      final h = _Harness();
      h.store.lease(_ids(80));
      h.store.lease(_ids(40, 'v'));
      t.elapse(const Duration(seconds: 1));
      expect(h.last.ids.length, 100);
      // All 40 newest are in; the 60 newest of the first 80 fill the rest.
      expect(h.last.ids.where((e) => e.startsWith('v')).length, 40);
      expect(h.last.ids.contains('u0'), isFalse);
      expect(h.last.ids.contains('u79'), isTrue);
    });
  });

  test('only changed ids notify', () {
    fakeAsync((t) {
      final h = _Harness();
      h.store.lease(['a', 'b']);
      t.elapse(const Duration(seconds: 1));
      var a = 0, b = 0;
      h.store.of('a').addListener(() => a++);
      h.store.of('b').addListener(() => b++);
      h.last.onData([
        {'id': 'a', 's': 'online'},
        {'id': 'b', 's': 'away', 'ls': 5},
      ]);
      expect([a, b], [1, 1]);
      h.last.onData([
        {'id': 'a', 's': 'online'},
        {'id': 'b', 's': 'offline', 'ls': 9},
      ]);
      expect([a, b], [1, 2]);
      expect(h.store.peek('b')!.lastSeen, 9);
      // Hidden: no s, no ls.
      h.last.onData([
        {'id': 'a'},
      ]);
      expect(h.store.peek('a'), isNull);
      expect(h.store.peek('b'), isNull);
    });
  });

  test('values outlive the subscription for the TTL, then go unknown', () {
    fakeAsync((t) {
      final h = _Harness();
      final l = h.store.lease(['a']);
      t.elapse(const Duration(seconds: 1));
      h.last.onData([
        {'id': 'a', 's': 'online'},
      ]);
      l.release();
      t.elapse(const Duration(seconds: 4)); // unsubscribed now
      t.elapse(const Duration(minutes: 1, seconds: 50));
      expect(h.store.peek('a')?.status, 'online');
      t.elapse(const Duration(seconds: 15));
      expect(h.store.peek('a'), isNull);
    });
  });

  test('function not found switches to legacy and stops subscribing', () {
    fakeAsync((t) {
      final h = _Harness();
      h.store.lease(['a']);
      t.elapse(const Duration(seconds: 1));
      var n = 0;
      h.store.addListener(() => n++);
      h.last.onError(Exception('Could not find public function for presenceApi:forUsers'));
      expect(h.store.legacy, isTrue);
      expect(n, 1);
      expect(h.last.cancelled, isTrue);
      h.store.lease(['b']);
      t.elapse(const Duration(seconds: 5));
      expect(h.subs.length, 1);
      // Other errors are the registry's to heal.
      final h2 = _Harness();
      h2.store.lease(['a']);
      t.elapse(const Duration(seconds: 1));
      h2.last.onError(Exception('timed out'));
      expect(h2.store.legacy, isFalse);
    });
  });

  test('clear forgets everything and voids old leases', () {
    fakeAsync((t) {
      final h = _Harness();
      final l = h.store.lease(['a']);
      t.elapse(const Duration(seconds: 1));
      h.last.onData([
        {'id': 'a', 's': 'online'},
      ]);
      h.store.clear();
      expect(h.last.cancelled, isTrue);
      expect(h.store.peek('a'), isNull);
      final l2 = h.store.lease(['a']);
      l.release(); // stale epoch: must not touch the new lease
      t.elapse(const Duration(seconds: 10));
      expect(h.subs.length, 2);
      expect(h.last.cancelled, isFalse);
      l2.release();
    });
  });
}
