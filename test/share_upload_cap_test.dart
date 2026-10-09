@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/file_meta.dart';

/// What this pins: **every copy of the share caps, and the native video
/// compressor's wiring.**
///
/// The share paths decide what to copy in natively, before Dart is running,
/// so the caps are repeated in Kotlin and Swift. A copy that drifts up copies
/// files Dart then refuses; one that drifts down drops files Dart would have
/// sent, with no error anywhere. The compressor is a channel name on four
/// sides and a Swift file in three Xcode targets, and any of those missing is
/// a build that is green and a big video that is silently refused.
///
/// A source scan, because none of the native halves run under `flutter test`.
void main() {
  int mb(String source, String pattern) {
    final match = RegExp(pattern).firstMatch(source);
    expect(match, isNotNull, reason: 'could not find $pattern');
    return int.parse(match!.group(1)!) * 1024 * 1024;
  }

  final kotlin = File(
    'android/app/src/main/kotlin/com/walhallaa/chattest20241220/ShareIntake.kt',
  ).readAsStringSync();
  final swift = File('ios/Shared/ShareGroup.swift').readAsStringSync();

  test('Android share caps equal the Dart caps', () {
    expect(
      mb(kotlin, r'MAX_UPLOAD_BYTES\s*=\s*(\d+)L\s*\*\s*1024\s*\*\s*1024'),
      kMaxFileUploadBytes,
    );
    expect(
      mb(kotlin, r'MAX_MEDIA_INTAKE_BYTES\s*=\s*(\d+)L\s*\*\s*1024\s*\*\s*1024'),
      kMaxMediaIntakeBytes,
    );
  });

  test('iOS share caps equal the Dart caps', () {
    expect(
      mb(swift, r'maxUploadBytes:\s*Int64\s*=\s*(\d+)\s*\*\s*1024\s*\*\s*1024'),
      kMaxFileUploadBytes,
    );
    expect(
      mb(swift,
          r'maxMediaIntakeBytes:\s*Int64\s*=\s*(\d+)\s*\*\s*1024\s*\*\s*1024'),
      kMaxMediaIntakeBytes,
    );
  });

  test('the intake cap is chosen by the same rule everywhere', () {
    expect(intakeCapFor('video/quicktime'), kMaxMediaIntakeBytes);
    expect(intakeCapFor('image/heic'), kMaxMediaIntakeBytes);
    expect(intakeCapFor('application/pdf'), kMaxFileUploadBytes);
    expect(kotlin.contains('mime.startsWith("image/") || mime.startsWith("video/")'),
        isTrue);
    expect(swift.contains('mimeType.hasPrefix("image/") || mimeType.hasPrefix("video/")'),
        isTrue);
  });

  test('every side of monkeyhub/video_shrink spells it the same way', () {
    const name = 'monkeyhub/video_shrink';
    for (final path in [
      'lib/media/video_shrink.dart',
      'ios/Runner/VideoShrink.swift',
      'macos/Runner/VideoShrink.swift',
      'android/app/src/main/kotlin/com/walhallaa/chattest20241220/VideoShrink.kt',
    ]) {
      expect(File(path).readAsStringSync().contains(name), isTrue, reason: path);
    }
    expect(
      File('ios/Runner/AppDelegate.swift').readAsStringSync()
          .contains('VideoShrink.register('),
      isTrue,
    );
    expect(
      File('macos/Runner/MainFlutterWindow.swift').readAsStringSync()
          .contains('VideoShrink.register('),
      isTrue,
    );
    expect(
      File('android/app/src/main/kotlin/com/walhallaa/chattest20241220/MainActivity.kt')
          .readAsStringSync()
          .contains('VideoShrink.register('),
      isTrue,
    );
  });

  test('the compressor is in every Xcode target that uses it', () {
    final ios = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    // App and share extension both compile the shared core.
    expect(
      RegExp(r'/\* VideoShrinkCore\.swift in Sources \*/,').allMatches(ios).length,
      2,
      reason: 'VideoShrinkCore.swift must be in the Runner and ShareExtension '
          'Sources phases',
    );
    expect(ios.contains('/* VideoShrink.swift in Sources */,'), isTrue);
    final mac = File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(mac.contains('/* VideoShrink.swift in Sources */,'), isTrue);
  });
}
