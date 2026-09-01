import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/native_call_handler.dart';

import 'fakes/fake_webrtc.dart';

/// The stale-mic (iOS orange dot) regression suite: every test here pins one
/// of the audited leak paths — teardown ordering (L1), the getUserMedia
/// races (L2/L3/L6), the no-session cleanup branch (L4), the throwing-track
/// release (L7), the group rebuild cap (B8) and the heartbeat self-eject.
/// The WebRTC boundary is faked through `getUserMediaFn`/`createPcFn`; the
/// backend through recording [_FakeCallApi]/[_FakeGroupApi]. No real device,
/// no real timers beyond microseconds.

/// A stream whose `dispose()` never answers — the Darwin `streamDispose`
/// whose capturer-stop completion never fires.
class _HangingDisposeStream extends FakeMediaStream {
  _HangingDisposeStream(super.tracks);

  @override
  Future<void> dispose() => Completer<void>().future;
}

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCallApi extends Fake implements CallApi {
  /// Ordered log of terminal-mutation invocations: 'cancel' | 'end' |
  /// 'reject'.
  final List<String> terminalCalls = [];

  /// When set, `cancelCall` returns this future instead of completing
  /// immediately (never-completing = the wedged-socket scenario).
  Future<String?>? cancelResult;

  /// Same control for `rejectCall`.
  Future<String?>? rejectResult;

  @override
  Future<String> initiateCall({
    required String callerId,
    required String calleeId,
    required String roomId,
    required String type,
  }) async =>
      'call-${terminalCalls.length}-$type-$roomId';

  @override
  Future<String?> cancelCall(
      {required String callId, required String userId}) {
    terminalCalls.add('cancel');
    return cancelResult ?? Future.value('cancelled');
  }

  @override
  Future<String?> endCall({required String callId, required String userId}) {
    terminalCalls.add('end');
    return Future.value('ended');
  }

  @override
  Future<String?> rejectCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) {
    terminalCalls.add('reject');
    return rejectResult ?? Future.value('rejected');
  }

  @override
  Future<void> sendCallSignal({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required String kind,
    required String payload,
    String? fromDeviceId,
    String? targetDeviceId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getIceConfig(String userId) async =>
      const [];

  @override
  Future<Subscription> subscribeActiveCall({
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();
}

Future<void> _pump([int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

CallService _newService(_FakeCallApi api) {
  final service = CallService(api: api)
    ..terminalNotifyTimeout = const Duration(milliseconds: 20)
    ..terminalNotifyRetryDelay = const Duration(milliseconds: 1)
    ..teardownUiHold = Duration.zero
    ..endNativeTimeout = const Duration(milliseconds: 20);
  service.attach(userId: 'me', displayName: 'Me');
  return service;
}

void main() {
  // flutter_webrtc's NativeLogsListener singleton wires an EventChannel the
  // first time the plugin's top-level helpers run (preferH264Codec) — it
  // needs a binary messenger even though the platform call itself just
  // MissingPluginExceptions its way into the helper's catch.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallService teardown', () {
    test('endCall releases the mic BEFORE the hanging cancel resolves',
        () async {
      final api = _FakeCallApi();
      // The wedged socket: cancel never completes.
      api.cancelResult = Completer<String?>().future;
      final service = _newService(api);
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        return stream;
      };
      service.createPcFn = (config, constraints) async => FakePeerConnection();

      await service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );
      expect(service.session?.status, CallStatus.outgoingRinging);

      // Ordering, not just boundedness: the mic must be off while endCall
      // is STILL lingering on the (hanging, not-yet-timed-out) notify — a
      // regression that merely bounds the old wait-then-release shape must
      // fail here, not only on an indefinite hang.
      var endCallDone = false;
      final ending = service.endCall().whenComplete(() => endCallDone = true);
      await _pump();
      expect(endCallDone, isFalse,
          reason: 'notify timeout (20ms) must not have fired yet');
      expect(api.terminalCalls, ['cancel'],
          reason: 'the mutation was kicked off first');
      expect(stream.micReleased, isTrue,
          reason: 'mic off while the network is still wedged');
      expect(service.localStream, isNull);
      await ending;
    });

    test('a wedged stream dispose neither blocks the PC close nor the belt',
        () async {
      // The macOS mic leak of 2026-08-31: the camera came down, the mic
      // stayed. Two things must hold whatever the capturer stop does — the
      // peer connection closes (the one release WebRTC itself performs), and
      // the module-level belt runs after it; and the ended session clears
      // on the UI hold rather than on a platform channel answering.
      final api = _FakeCallApi();
      final service = _newService(api)
        ..disposeStepTimeout = const Duration(milliseconds: 20);
      final stream =
          _HangingDisposeStream([FakeMediaStreamTrack(kind: 'audio')]);
      final pc = FakePeerConnection();
      final beltLog = <String>[];
      service.stopMicCaptureFn = () async {
        beltLog.add(pc.closed ? 'belt-after-close' : 'belt-before-close');
      };
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        return stream;
      };
      service.createPcFn = (config, constraints) async => pc;

      await service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );
      await service.endCall();

      expect(pc.closed, isTrue,
          reason: 'close must not queue behind the wedged dispose');
      expect(
          stream
              .getAudioTracks()
              .every((t) => (t as FakeMediaStreamTrack).stopped),
          isTrue);
      expect(beltLog, ['belt-after-close']);
      await _pump();
      expect(service.session, isNull,
          reason: 'the ended session clears on the hold, not the channel');
    });

    test('the belt stays off while a group call is live in the process',
        () async {
      NativeCallHandler.groupCallActiveProbe = () => true;
      addTearDown(() => NativeCallHandler.groupCallActiveProbe = () => false);
      final api = _FakeCallApi();
      final service = _newService(api);
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      var beltRuns = 0;
      service.stopMicCaptureFn = () async => beltRuns++;
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        return stream;
      };
      service.createPcFn = (config, constraints) async => FakePeerConnection();

      await service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );
      await service.endCall();
      expect(stream.micReleased, isTrue);
      expect(beltRuns, 0,
          reason: 'the two call paths share one audio-device module');
    });

    test("a server-converted cancel ('ended') triggers no duplicate end",
        () async {
      final api = _FakeCallApi();
      // The accept/cancel race, resolved server-side: cancel auto-converted.
      api.cancelResult = Future.value('ended');
      final service = _newService(api);
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        return stream;
      };
      service.createPcFn = (config, constraints) async => FakePeerConnection();

      await service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );
      await service.endCall();
      await _pump();

      expect(api.terminalCalls, ['cancel']);
      expect(stream.micReleased, isTrue);
    });

    test('reject releases the mic before the hanging mutation resolves',
        () async {
      final api = _FakeCallApi();
      api.rejectResult = Completer<String?>().future;
      final service = _newService(api);
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      // An incoming session mid-accept: media acquired, then decline.
      service.debugSetLocalStreamForTest(stream);
      service.handleRemoteSignal({
        '_id': 's1',
        'callId': 'call-in',
        'fromUserId': 'peer',
        'kind': 'invite',
        'payload': '{"callerName":"Peer","type":"audio","roomId":"r1"}',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _pump();
      expect(service.session?.status, CallStatus.incomingRinging);

      var rejectDone = false;
      final rejecting =
          service.reject().whenComplete(() => rejectDone = true);
      await _pump();
      expect(rejectDone, isFalse);
      expect(api.terminalCalls, ['reject']);
      expect(stream.micReleased, isTrue,
          reason: 'declining must not wait on the network to drop the mic');
      await rejecting;

      // Double-tap decline: the first pass owns the teardown.
      await service.reject();
      expect(api.terminalCalls, ['reject']);
    });

    test('initiate failure cancels the backend row it already created',
        () async {
      final api = _FakeCallApi();
      final service = _newService(api);
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        throw StateError('camera exploded');
      };
      service.createPcFn = (config, constraints) async => FakePeerConnection();

      await expectLater(
        service.initiate(
          peerUserId: 'peer',
          peerName: 'Peer',
          roomId: 'room1',
          kind: CallMediaKind.audio,
        ),
        throwsStateError,
      );
      await _pump();

      // The row was reserved before media setup — its failure must cancel
      // it (the callee is already ringing) rather than strand it.
      expect(api.terminalCalls, contains('cancel'));
      expect(service.session, isNull);
    });

    test('endCall is a no-op on an already-terminal session (double tap)',
        () async {
      final api = _FakeCallApi();
      final service = _newService(api);
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        return stream;
      };
      service.createPcFn = (config, constraints) async => FakePeerConnection();
      // Non-zero hold so the terminal session is still visible to the
      // second tap.
      service.teardownUiHold = const Duration(milliseconds: 50);

      await service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );
      await service.endCall();
      await service.endCall();
      await _pump();

      // Exactly one terminal mutation of any verb — without the guard the
      // second tap would send an `end` (the session reads terminal, so the
      // preferCancel branch flips), which a cancel-only count missed.
      expect(api.terminalCalls, ['cancel']);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    test('a stream resolving after endCall is stopped and never attached',
        () async {
      final api = _FakeCallApi();
      final service = _newService(api);
      final gate = Completer<void>();
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      final pc = FakePeerConnection();
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        await gate.future;
        return stream;
      };
      service.createPcFn = (config, constraints) async => pc;

      final initiated = service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );
      await _pump();
      expect(service.session?.status, CallStatus.outgoingRinging);

      // Cancel while getUserMedia is still in flight…
      await service.endCall();
      // …then the acquisition lands, late.
      gate.complete();
      await initiated;

      expect(stream.micReleased, isTrue,
          reason: 'the late stream must be stopped at the acquisition site');
      expect(service.localStream, isNull);
      expect(pc.addedTracks, isEmpty,
          reason: 'a dead call must never receive tracks');
    });

    test('cancel → instant redial never leaks the first call\'s stream',
        () async {
      final api = _FakeCallApi();
      final service = _newService(api);
      final gate1 = Completer<void>();
      final stream1 = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')],
          id: 'stream1');
      final stream2 = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')],
          id: 'stream2');
      final pcs = <FakePeerConnection>[];
      var acquisition = 0;
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        acquisition++;
        if (acquisition == 1) {
          await gate1.future;
          return stream1;
        }
        return stream2;
      };
      service.createPcFn = (config, constraints) async {
        final pc = FakePeerConnection();
        pcs.add(pc);
        return pc;
      };

      // Call #1: cancel while its getUserMedia is in flight.
      final first = service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );
      await _pump();
      await service.endCall();
      await _pump();

      // Call #2: redial immediately; completes normally.
      await service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );

      // Call #1's acquisition finally lands.
      gate1.complete();
      await first;
      await _pump();

      expect(stream1.micReleased, isTrue,
          reason: 'the superseded stream must be stopped, not clobbered over');
      expect(stream2.disposed, isFalse,
          reason: 'the live call must keep its media');
      expect(service.localStream, same(stream2));
      expect(pcs, hasLength(2));
      // The new call's PC saw only the new call's stream.
      expect(pcs[1].addedStreams.toSet(), {stream2});
      expect(pcs[1].addedStreams, isNot(contains(stream1)));
    });

    test('endCall with no session still disposes straggler media', () async {
      final api = _FakeCallApi();
      final service = _newService(api);
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      service.debugSetLocalStreamForTest(stream);

      await service.endCall();

      expect(stream.micReleased, isTrue);
      expect(service.localStream, isNull);
    });

    test('one throwing track never skips the rest of the release', () async {
      final api = _FakeCallApi();
      final service = _newService(api);
      final audio = FakeMediaStreamTrack(kind: 'audio');
      final stream = FakeMediaStream([
        // Video first — its stop() throws, like the Android OEM bug. The
        // audio track after it must still be stopped.
        FakeMediaStreamTrack(kind: 'video', throwOnStop: StateError('boom')),
        audio,
      ]);
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        return stream;
      };
      service.createPcFn = (config, constraints) async => FakePeerConnection();

      await service.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.video,
      );
      await service.endCall();

      expect(audio.stopped, isTrue);
      expect(stream.disposed, isTrue);
    });
  });

  group('GroupCallService teardown', () {
    test('leaveCall releases the mic BEFORE the hanging leave resolves',
        () async {
      final api = _FakeGroupApi();
      api.leaveResult = Completer<void>().future;
      final service = _newGroupService(api);
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        return stream;
      };

      await service.joinCall('gc1');
      expect(service.inCall, isTrue);

      // Same ordering pin as the 1:1 test: mic off while leaveCall is
      // still lingering on the not-yet-timed-out notify.
      var leaveDone = false;
      final leaving =
          service.leaveCall().whenComplete(() => leaveDone = true);
      await _pump();
      expect(leaveDone, isFalse);
      expect(api.leaveCalls, 1, reason: 'the mutation was kicked off first');
      expect(stream.micReleased, isTrue);
      expect(service.inCall, isFalse);
      expect(service.localStream, isNull);
      await leaving;
    });

    test('leave during in-flight getUserMedia orphans nothing', () async {
      final api = _FakeGroupApi();
      final service = _newGroupService(api);
      final gate = Completer<void>();
      final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
      service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
        await gate.future;
        return stream;
      };

      final joined = service.joinCall('gc1');
      await _pump();
      await service.leaveCall();
      gate.complete();
      await joined;
      await _pump();

      expect(stream.micReleased, isTrue,
          reason: 'the late stream must be stopped at the acquisition site');
      expect(service.inCall, isFalse);
      expect(service.localStream, isNull);
    });

    test('peer link rebuilds are capped with a fresh budget each time', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final service = _newGroupService(api);
        final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
        service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
          return stream;
        };
        final pcs = <FakePeerConnection>[];
        service.createPcFn = (config, constraints) async {
          final pc = FakePeerConnection();
          pcs.add(pc);
          return pc;
        };

        unawaited(service.joinCall('gc1'));
        async.flushMicrotasks();
        // Roster delivers one remote peer → a link is built.
        api.roster!({
          'groupCallId': 'gc1',
          'status': 'active',
          'participants': [
            {'userId': 'me', 'status': 'joined', 'name': 'Me'},
            {'userId': 'zz-peer', 'status': 'joined', 'name': 'Peer'},
          ],
        });
        async.flushMicrotasks();
        expect(pcs, hasLength(1));
        final peer = service.peers['zz-peer']!;

        // Drive every link this peer ever gets to Failed, forever.
        void failCurrentLink() {
          final pc = pcs.last;
          pc.onConnectionState
              ?.call(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
        }

        // Each recovery cycle: 3 restart attempts (0s, 4s, 10s, +8s final
        // pass) then abandon → rebuild. Fail the fresh link immediately.
        var lastCount = 0;
        for (var cycle = 0; cycle < 6; cycle++) {
          if (pcs.length != lastCount) {
            lastCount = pcs.length;
            failCurrentLink();
          }
          async.elapse(const Duration(seconds: 30));
          async.flushMicrotasks();
        }

        // Initial link + 2 rebuilds, then the cap: the link stays down
        // rather than churning forever — and the call itself survives.
        expect(pcs, hasLength(3));
        expect(peer.pc, isNull);
        expect(service.inCall, isTrue);
        // Each rebuild got a fresh recovery budget (the instant-abandon
        // loop would have burned through dozens of PCs by now).
        expect(peer.rebuildCount, greaterThan(2));

        unawaited(service.leaveCall());
        async.flushMicrotasks();
      });
    });

    test('four failed heartbeats self-eject and release the mic', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        api.heartbeatError = StateError('backend unreachable');
        final service = _newGroupService(api);
        final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
        service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
          return stream;
        };

        unawaited(service.joinCall('gc1'));
        async.flushMicrotasks();
        expect(service.inCall, isTrue);

        // 4 beats × 15s. The roster subscription is silent (dead) — the
        // heartbeat is the only thing left that can notice.
        async.elapse(const Duration(seconds: 61));
        async.flushMicrotasks();

        expect(service.inCall, isFalse);
        expect(stream.micReleased, isTrue);
      });
    });

    test("heartbeat answering 'not-in-call' ejects immediately", () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        api.heartbeatStatus = 'not-in-call';
        final service = _newGroupService(api);
        final stream = FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
        service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async {
          return stream;
        };

        unawaited(service.joinCall('gc1'));
        async.flushMicrotasks();
        expect(service.inCall, isTrue);

        async.elapse(const Duration(seconds: 16));
        async.flushMicrotasks();

        expect(service.inCall, isFalse);
        expect(stream.micReleased, isTrue);
      });
    });
  });
}

GroupCallService _newGroupService(_FakeGroupApi api) {
  final service = GroupCallService(api: api)
    ..leaveNotifyTimeout = const Duration(milliseconds: 20);
  service.attach(userId: 'me');
  return service;
}

class _FakeGroupApi extends Fake implements GroupCallApi {
  int leaveCalls = 0;
  Future<void>? leaveResult;
  Object? heartbeatError;
  String heartbeatStatus = 'ok';

  /// Captured roster callback — tests drive membership through it.
  void Function(Map<String, dynamic>? roster)? roster;

  @override
  Future<({String type, String roomId})> join({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async =>
      (type: 'audio', roomId: 'room1');

  @override
  Future<void> leave({
    required String groupCallId,
    required String userId,
  }) {
    leaveCalls++;
    return leaveResult ?? Future.value();
  }

  @override
  Future<String?> heartbeat({
    required String groupCallId,
    required String userId,
  }) async {
    final e = heartbeatError;
    if (e != null) throw e;
    return heartbeatStatus;
  }

  @override
  Future<void> sendSignal({
    required String groupCallId,
    required String fromUserId,
    required String toUserId,
    required String kind,
    required String payload,
    String? fromDeviceId,
    String? targetDeviceId,
  }) async {}

  @override
  Future<void> consumeSignals({
    required List<String> signalIds,
    required String userId,
  }) async {}

  @override
  Future<Subscription> subscribeSignals({
    required String userId,
    String? deviceId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();

  @override
  Future<Subscription> subscribeRoster({
    required String groupCallId,
    required String userId,
    required void Function(Map<String, dynamic>? roster) onRoster,
    void Function(Object error)? onError,
  }) async {
    roster = onRoster;
    return _FakeSubscription();
  }

  @override
  Future<Subscription> subscribePendingInvite({
    required String userId,
    required void Function(Map<String, dynamic>? invite) onInvite,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();
}
