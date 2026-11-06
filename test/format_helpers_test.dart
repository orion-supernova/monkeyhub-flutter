import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/format/duration_format.dart';
import 'package:monkeyhub/models/chat_user.dart';

void main() {
  group('formatClock', () {
    test('m:ss under an hour', () {
      expect(formatClock(Duration.zero), '0:00');
      expect(formatClock(const Duration(seconds: 7)), '0:07');
      expect(formatClock(const Duration(minutes: 12, seconds: 41)), '12:41');
      expect(formatClock(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('h:mm:ss from an hour up', () {
      expect(formatClock(const Duration(hours: 1)), '1:00:00');
      expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
    });

    test('negative clamps to zero, sub-second truncates', () {
      expect(formatClock(const Duration(seconds: -5)), '0:00');
      expect(formatClock(const Duration(milliseconds: 1999)), '0:01');
    });
  });

  group('initialOf', () {
    test('uppercases the first character', () {
      expect(initialOf('alice'), 'A');
      expect(initialOf('  bob'), 'B');
    });

    test('? when empty', () {
      expect(initialOf(''), '?');
      expect(initialOf('   '), '?');
    });

    test('keeps a whole grapheme', () {
      expect(initialOf('👨‍👩‍👧 family'), '👨‍👩‍👧');
      expect(initialOf('éclair'), 'É');
    });
  });
}
