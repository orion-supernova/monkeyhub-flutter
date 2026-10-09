@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/file_meta.dart';

/// What this pins: the two copies of the upload cap, and the one channel name
/// three files have to agree on.
///
/// Both are duplicated for a reason and both fail silently when they drift.
///
///  * **The cap.** `DropDestination.swift` refuses (and declines to copy)
///    anything past it during `performDragOperation`, which runs before Dart
///    is consulted at all — copying twenty-five megabytes so Dart can refuse
///    it a frame later is disk churn with no outcome. If the Swift number
///    drifts UP, files Dart will refuse get copied anyway; if it drifts DOWN,
///    files Dart would accept arrive with no bytes behind them and vanish.
///  * **The channel name.** A typo on either side is a drag that produces
///    nothing at all: no error, no log line, and a green build on both.
///
/// A source scan because neither the Swift side nor a real drag exists under
/// `flutter test`. Same shape and reasoning as `upload_cap_test.dart` and
/// `video_poster_gate_test.dart`, which this sits beside deliberately.
void main() {
  final swift = File('macos/Runner/DropDestination.swift').readAsStringSync();

  test('the macOS staging cap equals the Dart upload cap', () {
    final match = RegExp(
      r'kMaxDropBytes:\s*Int\s*=\s*(\d+)\s*\*\s*1024\s*\*\s*1024',
    ).firstMatch(swift);

    expect(
      match,
      isNotNull,
      reason: 'kMaxDropBytes moved or changed shape in DropDestination.swift. '
          'It mirrors kMaxFileUploadBytes, so this test has to keep being '
          'able to read it.',
    );

    expect(
      int.parse(match!.group(1)!) * 1024 * 1024,
      kMaxFileUploadBytes,
      reason: 'The Swift drag-staging cap and kMaxFileUploadBytes disagree. '
          'Whichever is larger decides what gets copied to disk, and whichever '
          'is smaller decides what actually sends — so a mismatch is either '
          'wasted I/O or a file that lands with nothing in it.',
    );
  });

  test('the macOS media cap equals the Dart media intake cap', () {
    final match = RegExp(
      r'kMaxDropMediaBytes:\s*Int\s*=\s*(\d+)\s*\*\s*1024\s*\*\s*1024',
    ).firstMatch(swift);
    expect(match, isNotNull, reason: 'kMaxDropMediaBytes moved or changed shape');
    expect(
      int.parse(match!.group(1)!) * 1024 * 1024,
      kMaxMediaIntakeBytes,
      reason: 'A dropped photo or video past the Swift cap is never copied; '
          'past the Dart one it is refused. They have to be the same number.',
    );
  });

  test('the web channel reads the cap rather than repeating it', () {
    // The browser has no native half, so there is no second constant to keep
    // in step — and there must never be one.
    final web = File('lib/drop/drop_channel_web.dart').readAsStringSync();
    expect(
      web.contains('kMaxFileUploadBytes'),
      isTrue,
      reason: 'the web drop channel must enforce the shared cap',
    );
    expect(
      RegExp(r'\d+\s*\*\s*1024\s*\*\s*1024').hasMatch(web),
      isFalse,
      reason: 'a third copy of the upload cap has appeared in the web channel',
    );
  });

  test('every side of monkeyhub/drop spells it the same way', () {
    const name = 'monkeyhub/drop';
    expect(swift.contains('"$name"'), isTrue, reason: 'DropDestination.swift');
    expect(
      File('lib/drop/drop_channel_io.dart')
          .readAsStringSync()
          .contains("'$name'"),
      isTrue,
      reason: 'drop_channel_io.dart',
    );
    expect(
      File('macos/Runner/MainFlutterWindow.swift')
          .readAsStringSync()
          .contains('DropDestination('),
      isTrue,
      reason: 'the window has to construct the destination or nothing '
          'registers for dragged types and no drag is ever seen',
    );
  });

  test('the macOS destination is in the Xcode target', () {
    // A Swift file that is in the folder and not in the build phase compiles
    // for nobody: the app builds clean, the window never registers, and drag
    // and drop is simply absent on macOS with no error anywhere.
    final project =
        File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(
      project.contains('DropDestination.swift in Sources'),
      isTrue,
      reason: 'DropDestination.swift is missing from the Runner target',
    );
  });
}
