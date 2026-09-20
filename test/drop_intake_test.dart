@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/drop/drop_intake.dart';
import 'package:monkeyhub/drop/drop_item.dart';

/// What this pins: that a file dropped on a chat ROW still has its bytes by
/// the time the room opens.
///
/// The hazard is specific and it deletes user data. `DropController` releases
/// the platform's staged copies as soon as the zone's `onDrop` completes, and
/// the chat-row zone's own work is over the instant it has selected a room —
/// long before a `RoomScreen` has mounted, collected the bundle and read it.
/// So the row's `onDrop` returns the INTAKE's future instead of its own, and
/// the room is what completes it.
///
/// Get that wrong in either direction and it is silent: complete too early and
/// macOS deletes the file mid-send, complete never and every drop leaks a copy
/// of itself into the temp directory for the life of the process.
void main() {
  const bundle = DropBundle(files: [
    DroppedFile(
      name: 'a.png',
      mimeType: 'image/png',
      size: 10,
      path: '/tmp/a.png',
    ),
  ]);

  setUp(() => DropIntake.instance.debugReset());
  tearDown(() => DropIntake.instance.debugReset());

  test('hands the bundle to the room it was staged for, once', () {
    final intake = DropIntake.instance;
    intake.stageFor('room-1', bundle);

    expect(intake.takeFor('room-2'), isNull, reason: 'wrong room');
    expect(intake.takeFor('room-1'), same(bundle));
    expect(intake.takeFor('room-1'), isNull, reason: 'a second collection');
  });

  test('the handoff stays open until the room says it is done', () async {
    final intake = DropIntake.instance;
    var released = false;
    unawaited(intake.stageFor('room-1', bundle).then((_) => released = true));

    // Collected, but not finished with: the bytes are still being read.
    intake.takeFor('room-1');
    await Future<void>.delayed(Duration.zero);
    expect(released, isFalse);

    intake.handoffComplete();
    await Future<void>.delayed(Duration.zero);
    expect(released, isTrue);
  });

  test('completing twice is harmless', () async {
    final intake = DropIntake.instance;
    final handoff = intake.stageFor('room-1', bundle);
    intake.handoffComplete();
    intake.handoffComplete();
    await expectLater(handoff, completes);
  });

  test('a second drop releases the first rather than stranding it', () async {
    final intake = DropIntake.instance;
    var firstReleased = false;
    unawaited(intake.stageFor('room-1', bundle).then((_) => firstReleased = true));

    intake.stageFor('room-2', bundle);
    await Future<void>.delayed(Duration.zero);
    expect(firstReleased, isTrue);
    // ...and the first room can no longer collect it.
    expect(intake.takeFor('room-1'), isNull);
    expect(intake.takeFor('room-2'), same(bundle));
  });

  test('notifies, so a room already on screen hears about it', () {
    // The desktop case that makes this a ChangeNotifier at all: selecting the
    // room that is already selected is a no-op, so there is no new
    // `RoomScreen` to check on mount.
    final intake = DropIntake.instance;
    var notified = 0;
    void listener() => notified++;
    intake.addListener(listener);
    addTearDown(() => intake.removeListener(listener));

    intake.stageFor('room-1', bundle);
    expect(notified, 1);
  });

  test('a reset releases whatever was in flight', () async {
    final intake = DropIntake.instance;
    final handoff = intake.stageFor('room-1', bundle);
    intake.debugReset();
    await expectLater(handoff, completes);
    expect(intake.takeFor('room-1'), isNull);
  });
}
