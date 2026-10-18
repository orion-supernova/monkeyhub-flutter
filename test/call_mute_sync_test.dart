import 'dart:convert';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/native_call_handler.dart';

import 'fakes/fake_webrtc.dart';

/// Report (2026-10-18, iPhone, 1:1 video, AirPods): "my mic button changed
/// and never fixed back". CallKit's mute event carries the state to be in;
/// it was applied as a toggle, so one repeating the call's current state
/// (iOS re-syncing mute across a route change, the AirPods' stem) flipped
/// the mic, and nothing told CallKit about in-app mutes, so the two stayed
/// apart. These pin the mute as a state, owned by the card's call, with the
/// app's own requests' echoes recognised.

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeApi extends Fake implements CallApi {
  @override
  Future<Subscription> subscribeActiveCall({
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();

  @override
  Future<String?> getCallStatus({
    required String callId,
    required String userId,
  }) async =>
      'ringing';

  @override
  Future<void> markCallRinging({
    required String callId,
    required String userId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getIceConfig(String userId) async =>
      const [];
}

Map<String, dynamic> _invite(String callId) => {
      '_id': 'invite-$callId',
      'callId': callId,
      'fromUserId': 'peer',
      'kind': 'invite',
      'payload': jsonEncode({'callerName': 'Zeynep', 'type': 'video'}),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallKitMuteLedger', () {
    test("the app's own request comes back as an echo, once", () {
      final l = CallKitMuteLedger();
      l.sent('u', true);
      expect(l.isEcho('u', true), isTrue);
      expect(l.isEcho('u', true), isFalse);
    });

    test('a quick mute then unmute: both echoes, in order', () {
      final l = CallKitMuteLedger();
      l.sent('u', true);
      l.sent('u', false);
      expect(l.isEcho('u', true), isTrue);
      expect(l.isEcho('u', false), isTrue);
    });

    test("a report that is not the next echo is the system's, and clears "
        "the card's queue", () {
      final l = CallKitMuteLedger();
      l.sent('u', true);
      expect(l.isEcho('u', false), isFalse);
      expect(l.isEcho('u', true), isFalse);
    });

    test('another card, or an expired request, is never an echo', () {
      var now = DateTime(2026, 10, 18);
      final l = CallKitMuteLedger(now: () => now);
      l.sent('u', true);
      expect(l.isEcho('other', true), isFalse);
      now = now.add(const Duration(seconds: 4));
      expect(l.isEcho('u', true), isFalse);
    });
  });

  group('mute follows CallKit as a state', () {
    late CallService service;
    late FakeMediaStreamTrack mic;
    final sent = <(String, bool)>[];
    final handler = NativeCallHandler.instance;
    final uuid = NativeCallHandler.derivedUuid('c1');

    setUpAll(() async {
      service = CallService.ensure(_FakeApi())
        ..teardownUiHold = Duration.zero
        ..endNativeTimeout = const Duration(milliseconds: 20)
        ..applyCallAudioFn = (kind,
                {required speakerOn, required headsetWins, callId}) async =>
            null;
      service.attach(userId: 'me', displayName: 'Me', deviceId: 'phone');
      await service.handleRemoteSignal(_invite('c1'));
      mic = FakeMediaStreamTrack(kind: 'audio');
      service.debugSetLocalStreamForTest(FakeMediaStream([mic], id: 'ls'));
      NativeCallHandler.nativeCallUiOverride = true;
      NativeCallHandler.iosNativeOverride = true;
      NativeCallHandler.muteCallFn = (u, m) async => sent.add((u, m));
      handler.debugRememberUuid('c1', uuid);
    });

    setUp(() async {
      await service.setMuted(false, fromSystem: true);
      sent.clear();
    });

    test("CallKit repeating the call's state changes nothing", () async {
      await handler.handleEvent(CallEventActionCallToggleMute(uuid, false));
      expect(service.session!.localMuted, isFalse);
      expect(mic.enabled, isTrue);
    });

    test('CallKit muting mutes, and saying it again keeps it muted',
        () async {
      await handler.handleEvent(CallEventActionCallToggleMute(uuid, true));
      expect(service.session!.localMuted, isTrue);
      expect(mic.enabled, isFalse);
      await handler.handleEvent(CallEventActionCallToggleMute(uuid, true));
      expect(service.session!.localMuted, isTrue);
      expect(mic.enabled, isFalse);
      // The system's own change is not reported back to it.
      expect(sent, isEmpty);
    });

    test("a mute for another call's card leaves this call alone", () async {
      await handler.handleEvent(CallEventActionCallToggleMute(
        NativeCallHandler.derivedUuid('someone-else'),
        true,
      ));
      expect(service.session!.localMuted, isFalse);
      expect(mic.enabled, isTrue);
    });

    test('the in-app button tells CallKit, and its echo is not reapplied',
        () async {
      await service.toggleMute();
      await service.toggleMute();
      expect(sent, [(uuid, true), (uuid, false)]);
      expect(service.session!.localMuted, isFalse);
      // The plugin's echoes of both, landing after the second tap.
      await handler.handleEvent(CallEventActionCallToggleMute(uuid, true));
      expect(service.session!.localMuted, isFalse);
      expect(mic.enabled, isTrue);
      await handler.handleEvent(CallEventActionCallToggleMute(uuid, false));
      expect(service.session!.localMuted, isFalse);
      // Then the AirPods stem: the system's, applied.
      await handler.handleEvent(CallEventActionCallToggleMute(uuid, true));
      expect(service.session!.localMuted, isTrue);
      expect(mic.enabled, isFalse);
    });

    test('a request re-sets the tracks even when the flag already agrees',
        () async {
      mic.enabled = false; // the track drifted from the flag
      await service.setMuted(false);
      expect(mic.enabled, isTrue);
      expect(sent, isEmpty);
    });
  });
}
