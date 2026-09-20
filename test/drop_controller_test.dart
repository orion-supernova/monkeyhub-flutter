@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/drop/drop_classifier.dart';
import 'package:monkeyhub/drop/drop_controller.dart';
import 'package:monkeyhub/drop/drop_item.dart';
import 'package:monkeyhub/drop/drop_zone_registry.dart';

/// What this pins: a whole drag, from the pointer arriving to the file landing.
///
/// The platform half is an `NSDraggingDestination` on one side and four DOM
/// listeners on the other, and neither exists under `flutter test` — so the
/// controller is driven through its own seams and the interesting parts are
/// the ones in between: which zone owns the pointer, when a plan is recomputed
/// against which policy, and what happens on release.
void main() {
  late DropZoneRegistry registry;
  late DropController drop;

  setUp(() {
    registry = DropZoneRegistry.forTest();
    drop = DropController.forTest(registry);
  });

  tearDown(() => drop.dispose());

  /// A zone over [rect], recording what it is told.
  ///
  /// The rectangle is supplied rather than measured: a handle reads its own
  /// position off a render tree, and there is no render tree here. This file
  /// is about the controller; `drop_zone_test.dart` is about the measuring.
  ({DropZoneHandle handle, List<String> log, List<DropBundle> drops}) zone(
    Rect rect, {
    int priority = 0,
    DropPolicy policy = DropPolicy.permissive,
    String? label,
  }) {
    final log = <String>[];
    final drops = <DropBundle>[];
    final handle = _FixedZone(
      rect: rect,
      policy: policy,
      priority: priority,
      label: label,
      onEnter: (local) => log.add('enter $local'),
      onMove: (local) => log.add('move $local'),
      onLeave: () => log.add('leave'),
      onDrop: (bundle) async => drops.add(bundle),
    );
    registry.register(handle);
    return (handle: handle, log: log, drops: drops);
  }

  const photo = DropSnapshot(
    items: [DropCandidate(name: 'a.png', size: 2048)],
    namesKnown: true,
    sizesKnown: true,
  );

  test('a drag over nothing has a session but no target', () {
    drop.debugEnter(photo, const Offset(10, 10));
    expect(drop.active, isTrue);
    expect(drop.target, isNull);
    expect(drop.plan.photoCount, 1);
  });

  test('an empty drag opens no session at all', () {
    drop.debugEnter(const DropSnapshot(), const Offset(10, 10));
    expect(drop.active, isFalse);
  });

  test('entering a zone tells it, and moving inside it keeps telling it', () {
    final a = zone(const Rect.fromLTWH(0, 0, 100, 100));
    drop.debugEnter(photo, const Offset(10, 10));
    expect(drop.target, same(a.handle));
    expect(a.log, ['enter Offset(10.0, 10.0)']);

    drop.debugMove(const Offset(40, 40));
    expect(a.log.last, 'move Offset(40.0, 40.0)');
  });

  test('crossing a boundary is a leave and an enter, once each', () {
    final a = zone(const Rect.fromLTWH(0, 0, 100, 100));
    final b = zone(const Rect.fromLTWH(100, 0, 100, 100));

    drop.debugEnter(photo, const Offset(10, 10));
    drop.debugMove(const Offset(150, 10));

    expect(a.log.last, 'leave');
    expect(b.log.single, 'enter Offset(50.0, 10.0)');
    expect(drop.target, same(b.handle));
  });

  test('leaving the window clears everything', () {
    final a = zone(const Rect.fromLTWH(0, 0, 100, 100));
    drop.debugEnter(photo, const Offset(10, 10));
    drop.debugLeave();

    expect(drop.active, isFalse);
    expect(drop.target, isNull);
    expect(drop.plan, DropPlan.empty);
    expect(a.log.last, 'leave');
  });

  test('the plan is computed against the zone the pointer is over', () {
    // The same file reads differently over two rooms, and it has to change the
    // moment the pointer crosses — this is the whole reason a plan is not
    // computed once per drag.
    zone(const Rect.fromLTWH(0, 0, 100, 100));
    zone(
      const Rect.fromLTWH(100, 0, 100, 100),
      policy: const DropPolicy(allowFiles: false),
    );

    drop.debugEnter(photo, const Offset(10, 10));
    expect(drop.plan.tone, DropTone.accept);

    drop.debugMove(const Offset(150, 10));
    expect(drop.plan.tone, DropTone.refuse);
    expect(drop.plan.refused.single.refusal, DropRefusal.notPermitted);
  });

  group('releasing', () {
    test('delivers to the zone under the drop, not the last one moved over',
        () async {
      // A flick into the window can arrive with no move in between, and a
      // platform is free to coalesce the last update away. Trusting the stale
      // target would put the file in the wrong chat.
      final a = zone(const Rect.fromLTWH(0, 0, 100, 100));
      final b = zone(const Rect.fromLTWH(100, 0, 100, 100));
      drop.debugEnter(photo, const Offset(10, 10));

      const bundle = DropBundle(files: [
        DroppedFile(
          name: 'a.png',
          mimeType: 'image/png',
          size: 2048,
          path: '/tmp/a.png',
        ),
      ]);
      await drop.debugPerform(bundle, const Offset(150, 10));

      expect(a.drops, isEmpty);
      expect(b.drops.single, same(bundle));
    });

    test('ends the session and records a landing', () async {
      zone(const Rect.fromLTWH(0, 0, 200, 200));
      drop.debugEnter(photo, const Offset(10, 10));
      await drop.debugPerform(
        const DropBundle(files: [
          DroppedFile(
            name: 'a.png',
            mimeType: 'image/png',
            size: 2048,
            path: '/tmp/a.png',
          ),
        ]),
        const Offset(20, 20),
      );

      expect(drop.active, isFalse);
      expect(drop.target, isNull);
      final landing = drop.landing.value;
      expect(landing, isNotNull);
      expect(landing!.accepted, isTrue);
      expect(landing.at, const Offset(20, 20));
      // Re-planned against what the drop finally revealed, which in a browser
      // is the first moment names and sizes exist at all.
      expect(landing.plan.namesKnown, isTrue);
      expect(landing.plan.photoCount, 1);
    });

    test('a drop on empty space is recorded as refused and delivered nowhere',
        () async {
      final a = zone(const Rect.fromLTWH(0, 0, 100, 100));
      drop.debugEnter(photo, const Offset(10, 10));
      await drop.debugPerform(
        const DropBundle(files: [
          DroppedFile(
            name: 'a.png',
            mimeType: 'image/png',
            size: 2048,
            path: '/tmp/a.png',
          ),
        ]),
        const Offset(500, 500),
      );

      expect(a.drops, isEmpty);
      expect(drop.landing.value!.accepted, isFalse);
    });

    test('a zone that throws still ends the session', () async {
      // Delivery is application code — an editor route, a send path, a cache
      // — and a throw there must not leave an overlay pinned over the app.
      registry.register(_FixedZone(
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        policy: DropPolicy.permissive,
        priority: 0,
        onEnter: (_) {},
        onMove: (_) {},
        onLeave: () {},
        onDrop: (_) async => throw StateError('nope'),
      ));

      drop.debugEnter(photo, const Offset(10, 10));
      await drop.debugPerform(
        const DropBundle(files: [
          DroppedFile(
            name: 'a.png',
            mimeType: 'image/png',
            size: 2048,
            path: '/tmp/a.png',
          ),
        ]),
        const Offset(20, 20),
      );

      expect(drop.active, isFalse);
    });

    test('a landing is cleared by serial, so a later one is not swallowed',
        () async {
      zone(const Rect.fromLTWH(0, 0, 200, 200));
      const bundle = DropBundle(files: [
        DroppedFile(
          name: 'a.png',
          mimeType: 'image/png',
          size: 2048,
          path: '/tmp/a.png',
        ),
      ]);
      drop.debugEnter(photo, const Offset(10, 10));
      await drop.debugPerform(bundle, const Offset(20, 20));
      final first = drop.landing.value!.serial;

      drop.debugEnter(photo, const Offset(10, 10));
      await drop.debugPerform(bundle, const Offset(20, 20));
      final second = drop.landing.value!.serial;
      expect(second, isNot(first));

      drop.clearLanding(first);
      expect(drop.landing.value, isNotNull, reason: 'the stale clear won');
      drop.clearLanding(second);
      expect(drop.landing.value, isNull);
    });
  });

  test('a zone that leaves the tree mid-drag is never called again', () {
    // A route popped, a chat row rebuilt, a pane the shell swapped out — all
    // ordinary things to happen while a file is in the air, and all of them
    // dispose the zone's notifier while this controller still holds the last
    // reference to its handle. Calling back into it then is a write to a
    // disposed `ValueNotifier`.
    final a = zone(const Rect.fromLTWH(0, 0, 100, 100));
    drop.debugEnter(photo, const Offset(10, 10));
    expect(drop.target, same(a.handle));

    registry.unregister(a.handle);
    a.log.clear();

    drop.debugLeave();
    expect(a.log, isEmpty);
    expect(drop.target, isNull);
  });

  test('a detached zone stops winning hit tests', () {
    final a = zone(const Rect.fromLTWH(0, 0, 100, 100));
    expect(registry.hitTest(const Offset(10, 10)), same(a.handle));
    registry.unregister(a.handle);
    expect(registry.hitTest(const Offset(10, 10)), isNull);
  });

  test('the pointer never rides on notifyListeners', () {
    // The reason there are two channels out of the controller at all: a drag
    // reports a position at the display's refresh rate, and rebuilding every
    // chat row sixty times a second for the length of one is not affordable.
    zone(const Rect.fromLTWH(0, 0, 200, 200));
    drop.debugEnter(photo, const Offset(10, 10));

    var rebuilds = 0;
    drop.addListener(() => rebuilds++);
    drop.debugMove(const Offset(11, 11));
    drop.debugMove(const Offset(12, 12));
    drop.debugMove(const Offset(13, 13));

    expect(rebuilds, 0);
    expect(drop.pointer.value, const Offset(13, 13));
  });
}

/// A handle whose rectangle is given rather than measured.
class _FixedZone extends DropZoneHandle {
  _FixedZone({
    required Rect rect,
    required super.policy,
    required super.priority,
    required super.onEnter,
    required super.onMove,
    required super.onLeave,
    required super.onDrop,
    super.label,
  })  : _rect = rect,
        super(key: GlobalKey());

  final Rect _rect;

  @override
  Rect? get rect => _rect;
}
