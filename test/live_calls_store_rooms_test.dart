import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/live_calls_store.dart';

class _Call {
  _Call(this.roomIds, this.onCalls, this.onError);
  final List<String>? roomIds;
  final void Function(List<Map<String, dynamic>>) onCalls;
  final void Function(Object) onError;
  bool cancelled = false;
}

void main() {
  late List<_Call> calls;
  final store = LiveCallsStore.instance;

  Future<void> attach() => store.attachWith((ids, onCalls, onError) async {
    final c = _Call(ids, onCalls, onError);
    calls.add(c);
    return () => c.cancelled = true;
  }, 'me');

  setUp(() {
    calls = [];
    store.detach();
  });
  tearDown(store.detach);

  test('nothing subscribes until rooms are known, then roomIds ride along',
      () async {
    await attach();
    expect(calls, isEmpty);

    store.syncRooms(['r2', 'r1']);
    await Future<void>.delayed(Duration.zero);
    expect(calls.single.roomIds, ['r1', 'r2']);
  });

  test('only a change of the SET resubscribes', () async {
    await attach();
    store.syncRooms(['r2', 'r1']);
    await Future<void>.delayed(Duration.zero);

    store.syncRooms(['r1', 'r2']);
    store.syncRooms(['r2', 'r1', 'r1']);
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));
    expect(calls.single.cancelled, isFalse);

    store.syncRooms(['r1', 'r2', 'r3']);
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(2));
    expect(calls.first.cancelled, isTrue);
    expect(calls.last.roomIds, ['r1', 'r2', 'r3']);
  });

  test('rooms known before attach are used by the first subscribe', () async {
    await attach();
    store.syncRooms(['a']);
    await Future<void>.delayed(Duration.zero);
    expect(calls.single.roomIds, ['a']);
  });

  test('a server that rejects roomIds falls back to every room', () async {
    await attach();
    store.syncRooms(['a', 'b']);
    await Future<void>.delayed(Duration.zero);
    calls.single.onError(Exception('ArgumentValidationError: roomIds'));
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(2));
    expect(calls.last.roomIds, isNull);
    // And it stays on that form when the set changes.
    store.syncRooms(['a', 'b', 'c']);
    await Future<void>.delayed(Duration.zero);
    expect(calls.last.roomIds, isNull);
  });

  test('detach cancels and forgets the rooms', () async {
    await attach();
    store.syncRooms(['a']);
    await Future<void>.delayed(Duration.zero);
    store.detach();
    expect(calls.single.cancelled, isTrue);
    await attach();
    expect(calls, hasLength(1)); // rooms were forgotten: nothing yet
  });
}
