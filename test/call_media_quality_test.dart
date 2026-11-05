import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_media.dart';
import 'package:monkeyhub/calls/call_models.dart';

void main() {
  _noRejectedConfigKeys();
  group('videoConstraintsFor', () {
    test('native platforms get bare numbers the plugins can read', () {
      // A `{ideal: n}` map reached iPhone and Mac as a 0x0 target, so the
      // camera ran its smallest format. Bare numbers are read everywhere.
      final c = videoConstraintsFor(VideoQualityTier.auto, web: false);
      expect(c['width'], 1280);
      expect(c['height'], 720);
      expect(c['frameRate'], 30);
      expect(c['facingMode'], 'user');
    });

    test('each tier asks for its own resolution', () {
      final hd = videoConstraintsFor(VideoQualityTier.hd1080, web: false);
      expect(hd['width'], 1920);
      expect(hd['height'], 1080);
    });

    test('rear camera keeps its facing', () {
      final c = videoConstraintsFor(
        VideoQualityTier.auto,
        back: true,
        web: false,
      );
      expect(c['facingMode'], 'environment');
    });

    test('the browser keeps the range form', () {
      final c = videoConstraintsFor(VideoQualityTier.auto, web: true);
      expect(c['width'], isA<Map>());
      expect((c['width'] as Map)['ideal'], 1280);
    });
  });

  group('orderOpusRedFirst', () {
    String id(String s) => s;

    test('puts RED, then Opus, then the rest', () {
      final out = orderOpusRedFirst(
        ['audio/opus', 'audio/G722', 'audio/red', 'audio/telephone-event'],
        id,
      );
      expect(out, [
        'audio/red',
        'audio/opus',
        'audio/G722',
        'audio/telephone-event',
      ]);
    });

    test('never drops a codec', () {
      final input = ['audio/opus', 'audio/PCMU', 'audio/RED', 'audio/CN'];
      expect(orderOpusRedFirst(input, id)!.toSet(), input.toSet());
    });

    test('leaves the order alone without RED or without Opus', () {
      expect(orderOpusRedFirst(['audio/opus', 'audio/PCMU'], id), isNull);
      expect(orderOpusRedFirst(['audio/red', 'audio/PCMU'], id), isNull);
    });
  });
}

/// 1.3.140: `enableDscp` + `iceBackupCandidatePairPingInterval` in the call
/// connection config made libwebrtc refuse the peer connection on iPhone,
/// and every call hung before its offer. Keep them out until a real device
/// says otherwise.
void _noRejectedConfigKeys() {
  test('call configs carry no keys libwebrtc rejected on device', () {
    for (final path in [
      'lib/calls/call_service.dart',
      'lib/calls/group_call_service.dart',
      'lib/calls/call_media.dart',
    ]) {
      final src = File(path).readAsStringSync();
      for (final key in ["'enableDscp'", "'iceBackupCandidatePairPingInterval'"]) {
        expect(src.contains(key), isFalse, reason: '$key in $path');
      }
    }
  });
}
