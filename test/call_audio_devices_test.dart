import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/calls/call_audio_devices.dart';
import 'package:monkeyhub/calls/call_media.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';

/// The pure parts of the in-call audio control: which glyph the button
/// shows for the real route, when it toggles and when it opens the route
/// sheet, how the native route lists parse, and the Android pin that keeps
/// a "not my earbuds" pick through re-applies.

const _earpiece = CallAudioRouteOption(
  kind: CallAudioOutputKind.earpiece,
  id: 'mic-uid',
  name: 'iPhone',
);
const _speaker = CallAudioRouteOption(
  kind: CallAudioOutputKind.speaker,
  id: '',
);
const _airpods = CallAudioRouteOption(
  kind: CallAudioOutputKind.bluetooth,
  id: 'airpods-uid',
  name: "Murat's AirPods Pro",
);

void main() {
  group('callAudioOutputKindFrom', () {
    test('reads iOS router names and Android AudioSwitch type names', () {
      const cases = {
        'receiver': CallAudioOutputKind.earpiece,
        'earpiece': CallAudioOutputKind.earpiece,
        'speaker': CallAudioOutputKind.speaker,
        'bluetooth': CallAudioOutputKind.bluetooth,
        'headphones': CallAudioOutputKind.headphones,
        'wired-headset': CallAudioOutputKind.headphones,
        'car': CallAudioOutputKind.car,
        'airplay': CallAudioOutputKind.airplay,
        'other': CallAudioOutputKind.other,
      };
      cases.forEach((name, kind) {
        expect(callAudioOutputKindFrom(name), kind, reason: name);
      });
    });

    test('no live session or an unknown name is unknown', () {
      expect(callAudioOutputKindFrom('none'), isNull);
      expect(callAudioOutputKindFrom(null), isNull);
      expect(callAudioOutputKindFrom('hdmi'), isNull);
    });
  });

  group('callAudioButtonLook', () {
    test('each real route has its own glyph; only the earpiece is unlit',
        () {
      final cases = {
        CallAudioOutputKind.speaker: (CallGlyphs.speakerOn, true),
        CallAudioOutputKind.earpiece: (CallGlyphs.speakerOff, false),
        CallAudioOutputKind.bluetooth: (CallGlyphs.routeBluetooth, true),
        CallAudioOutputKind.headphones: (CallGlyphs.routeWired, true),
        CallAudioOutputKind.car: (CallGlyphs.routeCar, true),
        CallAudioOutputKind.airplay: (CallGlyphs.routeAirPlay, true),
        CallAudioOutputKind.other: (CallGlyphs.routeOther, true),
      };
      cases.forEach((kind, want) {
        // The real route wins over the flag, whichever way the flag reads.
        for (final flag in [true, false]) {
          final look = callAudioButtonLook(output: kind, speakerOn: flag);
          expect(look.icon, want.$1, reason: '$kind flag=$flag');
          expect(look.active, want.$2, reason: '$kind flag=$flag');
        }
      });
    });

    test('AirPods draw as AirPods; any other headset as headphones', () {
      expect(
        callAudioButtonLook(
          output: CallAudioOutputKind.bluetooth,
          speakerOn: false,
          name: "Murat's AirPods Pro",
        ).glyph,
        const CallTrayGlyph.audio(CallAudioGlyphRoute.airpods),
      );
      expect(
        callAudioButtonLook(
          output: CallAudioOutputKind.bluetooth,
          speakerOn: false,
          name: 'Galaxy Buds2',
        ).glyph,
        const CallTrayGlyph.audio(CallAudioGlyphRoute.headphones),
      );
    });

    test('a headset mic is where the voice comes from on iOS, else the '
        'output stands for it', () {
      expect(callMicOnHeadset('bluetooth'), isTrue);
      expect(callMicOnHeadset('headset'), isTrue);
      expect(callMicOnHeadset('builtIn'), isFalse);
      expect(callMicFollowsOutput(CallAudioOutputKind.bluetooth), isTrue);
      expect(callMicFollowsOutput(CallAudioOutputKind.airplay), isFalse);
      expect(callMicFollowsOutput(CallAudioOutputKind.speaker), isFalse);
    });

    test('Bluetooth and wired headsets read apart', () {
      expect(CallGlyphs.routeBluetooth, isNot(CallGlyphs.routeWired));
    });

    test('an unknown route falls back to the flag, as the button always was',
        () {
      final on = callAudioButtonLook(output: null, speakerOn: true);
      expect(on.icon, CallGlyphs.speakerOn);
      expect(on.active, isTrue);
      final off = callAudioButtonLook(output: null, speakerOn: false);
      expect(off.icon, CallGlyphs.speakerOff);
      expect(off.active, isFalse);
    });

    test('the sheet shows the earpiece as the phone itself', () {
      expect(
        callAudioRouteGlyph(CallAudioOutputKind.earpiece),
        CallGlyphs.routePhone,
      );
      expect(
        callAudioRouteGlyph(CallAudioOutputKind.bluetooth),
        CallGlyphs.routeBluetooth,
      );
    });
  });

  group('callAudioNeedsPicker', () {
    test('earpiece and speaker only: the button toggles', () {
      expect(callAudioNeedsPicker(const [_earpiece, _speaker]), isFalse);
      // An iPad: the speaker alone.
      expect(callAudioNeedsPicker(const [_speaker]), isFalse);
      // Nothing reported (an older native build).
      expect(callAudioNeedsPicker(const []), isFalse);
    });

    test('any headset route: the button opens the sheet', () {
      expect(
        callAudioNeedsPicker(const [_earpiece, _speaker, _airpods]),
        isTrue,
      );
      for (final kind in [
        CallAudioOutputKind.headphones,
        CallAudioOutputKind.car,
        CallAudioOutputKind.airplay,
        CallAudioOutputKind.other,
      ]) {
        expect(
          callAudioNeedsPicker([
            _speaker,
            CallAudioRouteOption(kind: kind, id: ''),
          ]),
          isTrue,
          reason: '$kind',
        );
      }
    });
  });

  group('iOS route maps', () {
    test('a route parses kind, uid, name and the check', () {
      final r = CallAudioRouteOption.fromMap({
        'kind': 'bluetooth',
        'uid': 'airpods-uid',
        'name': "Murat's AirPods Pro",
        'selected': true,
      });
      expect(r, _airpods.copyWith(selected: true));
      expect(r!.isHeadset, isTrue);
    });

    test('an unknown kind is dropped, an empty name is no name', () {
      expect(CallAudioRouteOption.fromMap({'kind': 'hdmi'}), isNull);
      final speaker =
          CallAudioRouteOption.fromMap({'kind': 'speaker', 'name': ''});
      expect(speaker!.name, isNull);
      expect(speaker.id, '');
      expect(speaker.selected, isFalse);
    });

    test('CallAudioRoute carries the port name and the raw routes', () {
      final route = CallAudioRoute.fromMap({
        'speaker': false,
        'headset': true,
        'output': 'bluetooth',
        'portName': "Murat's AirPods Pro",
        'reason': 'newDevice',
        'routes': [
          {'kind': 'receiver', 'uid': 'mic', 'name': 'iPhone'},
          {'kind': 'speaker', 'uid': ''},
          'junk',
        ],
      });
      expect(route.portName, "Murat's AirPods Pro");
      expect(route.routes, hasLength(2));
      expect(route.reason, CallAudioRouteReason.newDevice);
    });

    test('an older native build sends neither and still parses', () {
      final route = CallAudioRoute.fromMap({
        'speaker': true,
        'headset': false,
        'output': 'speaker',
        'reason': 'override',
      });
      expect(route.portName, isNull);
      expect(route.routes, isEmpty);
    });
  });

  group('androidRoutesFrom', () {
    test('phone first, then speaker, then headsets; the current one checked',
        () {
      final routes = androidRoutesFrom(
        const [
          (id: 'bluetooth', label: 'Galaxy Buds2'),
          (id: 'speaker', label: 'Speakerphone'),
          (id: 'earpiece', label: 'Earpiece'),
          (id: 'wired-headset', label: 'Wired Headset'),
        ],
        current: 'bluetooth',
      );
      expect([for (final r in routes) r.id],
          ['earpiece', 'speaker', 'bluetooth', 'wired-headset']);
      expect([for (final r in routes) r.selected], [false, false, true, false]);
      expect(callAudioNeedsPicker(routes), isTrue);
    });

    test("only a Bluetooth device keeps its name; AudioSwitch's are English",
        () {
      final routes = androidRoutesFrom(
        const [
          (id: 'earpiece', label: 'Earpiece'),
          (id: 'bluetooth', label: 'Galaxy Buds2'),
          (id: 'wired-headset', label: 'Wired Headset'),
        ],
        current: null,
      );
      expect([for (final r in routes) r.name], [null, 'Galaxy Buds2', null]);
      expect(routes.any((r) => r.selected), isFalse);
    });

    test('duplicates and unknown devices are dropped', () {
      final routes = androidRoutesFrom(
        const [
          (id: 'speaker', label: 'Speakerphone'),
          (id: 'speaker', label: 'Speakerphone'),
          (id: 'usb-dock', label: 'Dock'),
        ],
        current: 'speaker',
      );
      expect(routes, hasLength(1));
      expect(callAudioNeedsPicker(routes), isFalse);
    });
  });

  group('checkedDeviceId', () {
    MediaDeviceInfo dev(String id) =>
        MediaDeviceInfo(deviceId: id, label: id, kind: 'audioinput');

    test('the session pick while it is still connected', () {
      expect(checkedDeviceId([dev('default'), dev('usb')], 'usb'), 'usb');
    });

    test("a pick that went away falls back to the browser's default", () {
      expect(checkedDeviceId([dev('default'), dev('usb')], 'gone'), 'default');
    });

    test('no default entry and no pick: nothing is claimed', () {
      expect(checkedDeviceId([dev('a'), dev('b')], null), isNull);
    });
  });

  group('Android pinned output', () {
    final log = <String>[];

    setUp(() {
      resetAndroidCallRoute();
      log.clear();
      androidSetSpeakerphoneOn = (enable) async => log.add('speaker($enable)');
      androidSetSpeakerphoneButPreferHeadset =
          () async => log.add('speakerUnlessHeadset');
      androidSelectAudioOutput = (id) async => log.add('select($id)');
      androidCallWindowSink = (state) async {};
    });

    tearDown(resetAndroidCallRoute);

    test('a pick off the speaker is re-asserted after every earpiece apply',
        () async {
      pinAndroidCallOutput('earpiece');
      await applyAndroidCallRoute(speakerOn: false, headsetWins: false);
      await applyAndroidCallRoute(speakerOn: false);
      expect(log, [
        'speaker(false)',
        'select(earpiece)',
        'speaker(false)',
        'select(earpiece)',
      ]);
    });

    test('the speaker side never re-asserts the pin', () async {
      pinAndroidCallOutput('bluetooth');
      await applyAndroidCallRoute(speakerOn: true, headsetWins: false);
      expect(log, ['speaker(true)']);
    });

    test('no pin: the route is exactly what it was', () async {
      await applyAndroidCallRoute(speakerOn: false);
      expect(log, ['speaker(false)']);
      expect(androidPinnedCallOutput, isNull);
    });

    test('the call ending forgets the pin', () async {
      pinAndroidCallOutput('bluetooth');
      resetAndroidCallRoute();
      expect(androidPinnedCallOutput, isNull);
      await applyAndroidCallRoute(speakerOn: false);
      expect(log, ['speaker(false)']);
    });
  });
}
