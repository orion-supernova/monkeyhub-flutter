import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/native_call_handler.dart';

/// The native call id is a cross-language contract: Dart derives it in
/// `NativeCallHandler.derivedUuid` and Kotlin derives it in
/// `CallFcmService.uuidForCallId` via `java.util.UUID.nameUUIDFromBytes`. A
/// card can be raised by one side and driven by the other, so if the two ever
/// disagree, `setCallConnected` / `endCall` silently address a call the plugin
/// has never heard of and the ringer gets stuck.
///
/// The expectations below are the values `UUID.nameUUIDFromBytes` produces —
/// they encode the Java behaviour, not ours, so they stay valid however this
/// file is refactored.
void main() {
  group('derivedUuid matches java.util.UUID.nameUUIDFromBytes', () {
    test('the empty name', () {
      expect(
        NativeCallHandler.derivedUuid(''),
        'd41d8cd9-8f00-3204-a980-0998ecf8427e',
      );
    });

    test('a short ASCII name', () {
      expect(
        NativeCallHandler.derivedUuid('hello'),
        '5d41402a-bc4b-3a76-b971-9d911017c592',
      );
    });

    test('a Convex-shaped call id', () {
      // The id from the Android call log that started all this.
      expect(
        NativeCallHandler.derivedUuid('kh718395wzn50zd89m2armhsq18bng58'),
        'b4098838-5140-312b-8cc6-1552bd39cf35',
      );
    });

    test('a non-ASCII name — pins the UTF-8 encoding', () {
      // Kotlin encodes with Charsets.UTF_8. A Latin-1 slip on either side
      // would still yield a well-formed UUID, just a different one.
      expect(
        NativeCallHandler.derivedUuid('çağrı'),
        '7ac703e1-9107-30e1-a466-8623c346e159',
      );
    });
  });

  group('derivedUuid', () {
    test('is stable across calls — a second process must agree', () {
      final once = NativeCallHandler.derivedUuid('jd7abc123');
      final twice = NativeCallHandler.derivedUuid('jd7abc123');
      expect(once, twice);
    });

    test('separates distinct calls', () {
      expect(
        NativeCallHandler.derivedUuid('jd7abc123'),
        isNot(NativeCallHandler.derivedUuid('jd7abc124')),
      );
    });

  });
}
