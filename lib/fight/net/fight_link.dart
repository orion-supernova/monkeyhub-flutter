import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../backend/call_api.dart';
import '../../backend/convex_client.dart';

enum FightLinkState { connecting, open, failed, closed }

/// What a fight driver needs from the pipe to the other phone. [FightLink]
/// is the real one (WebRTC); tests use an in-memory pair.
abstract class FightPipe {
  set onInput(void Function(Uint8List bytes)? f);
  set onControl(void Function(Map<String, dynamic> msg)? f);
  DateTime get lastHeard;
  ValueListenable<FightLinkState> get state;
  void sendInput(Uint8List bytes);
  void sendControl(Map<String, dynamic> msg);
}

/// The phone-to-phone pipe of an online fight: one WebRTC peer connection,
/// data only, signalled through `fightSignals` (offer, answer, ICE).
///
/// Two channels:
///  * `fight`: unordered, packets live at most [_inputLifetimeMs]. Rollback
///    input packets repeat the last 8 inputs, so a lost or late one is
///    simply superseded; retransmitting it would only add delay.
///  * `ctl`: ordered and reliable, small JSON control messages (ping, go,
///    bye).
///
/// Seat 0 offers, seat 1 answers: deterministic, so there is never glare.
/// The first device of the peer that answers or offers is the one this link
/// talks to; signals from the peer's other devices are ignored.
class FightLink implements FightPipe {
  FightLink({
    required this.matchId,
    required this.userId,
    required this.peerUserId,
    required this.offerer,
    required this.deviceId,
    ConvexBackend? backend,
  }) : _cv = backend ?? ConvexBackend.instance;

  final String matchId, userId, peerUserId, deviceId;
  final bool offerer;
  final ConvexBackend _cv;

  static const int _inputLifetimeMs = 120;
  static const Duration connectTimeout = Duration(seconds: 25);

  @override
  final ValueNotifier<FightLinkState> state = ValueNotifier(FightLinkState.connecting);

  /// Input packets from the peer.
  @override
  void Function(Uint8List bytes)? onInput;

  /// Control messages from the peer.
  @override
  void Function(Map<String, dynamic> msg)? onControl;

  /// When the last packet of any kind arrived (for the lost-connection timer).
  @override
  DateTime lastHeard = DateTime.now();

  RTCPeerConnection? _pc;
  RTCDataChannel? _fight, _ctl;
  Subscription? _sub;
  String? _peerDevice;
  bool _remoteSet = false, _closed = false;
  final List<RTCIceCandidate> _pendingRemoteIce = [];
  final List<Map<String, dynamic>> _iceOut = [];
  Timer? _iceFlush, _timeout;
  final Set<String> _seen = {};
  Future<void> _queue = Future.value();

  Future<void> start() async {
    _timeout = Timer(connectTimeout, () {
      if (state.value == FightLinkState.connecting) _fail('timeout');
    });
    _sub = await _cv.subscribe(
      'fightSignals:forMe',
      {'matchId': matchId, 'viewerUserId': userId},
      onData: (raw) {
        final rows = ((raw as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
        // One at a time, in order: an answer must land before its candidates.
        _queue = _queue.then((_) => _handle(rows));
      },
      onError: (e) => debugPrint('FightLink: signal subscription error: $e'),
    );
    if (offerer) {
      final pc = await _createPc();
      _attach(await pc.createDataChannel('fight', _fightInit()));
      _attach(await pc.createDataChannel('ctl', RTCDataChannelInit()..ordered = true..binaryType = 'text'));
      final offer = await pc.createOffer({});
      await pc.setLocalDescription(offer);
      await _signal('offer', {'sdp': offer.sdp, 'type': offer.type});
    }
  }

  static RTCDataChannelInit _fightInit() => RTCDataChannelInit()
    ..ordered = false
    ..maxRetransmitTime = _inputLifetimeMs
    ..binaryType = 'binary';

  Future<RTCPeerConnection> _createPc() async {
    List<Map<String, dynamic>> servers;
    try {
      servers = await CallApi(_cv).getIceConfig(userId);
    } catch (e) {
      debugPrint('FightLink: ICE config fetch failed, STUN only: $e');
      servers = const [
        {'urls': 'stun:stun.l.google.com:19302'},
      ];
    }
    final pc = _pc = await createPeerConnection({
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    }, {});
    pc.onIceCandidate = (c) {
      if (c.candidate == null || _closed) return;
      _iceOut.add({'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
      // Batch: a burst of candidates becomes one write.
      _iceFlush ??= Timer(const Duration(milliseconds: 120), _flushIce);
    };
    pc.onDataChannel = _attach;
    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) _fail('ice failed');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint('FightLink: disconnected (may recover)');
      }
    };
    return pc;
  }

  void _attach(RTCDataChannel ch) {
    if (ch.label == 'fight') {
      _fight = ch;
      ch.onMessage = (m) {
        if (!m.isBinary) return;
        lastHeard = DateTime.now();
        onInput?.call(m.binary);
      };
    } else if (ch.label == 'ctl') {
      _ctl = ch;
      ch.onMessage = (m) {
        if (m.isBinary) return;
        lastHeard = DateTime.now();
        try {
          onControl?.call((jsonDecode(m.text) as Map).cast<String, dynamic>());
        } catch (_) {}
      };
    }
    ch.onDataChannelState = (_) => _checkOpen();
    _checkOpen();
  }

  void _checkOpen() {
    final open = _fight?.state == RTCDataChannelState.RTCDataChannelOpen && _ctl?.state == RTCDataChannelState.RTCDataChannelOpen;
    if (open && state.value == FightLinkState.connecting) {
      _timeout?.cancel();
      lastHeard = DateTime.now();
      state.value = FightLinkState.open;
    }
    final closed = _fight?.state == RTCDataChannelState.RTCDataChannelClosed || _ctl?.state == RTCDataChannelState.RTCDataChannelClosed;
    if (closed && state.value == FightLinkState.open) {
      state.value = FightLinkState.closed;
    }
  }

  Future<void> _handle(List<Map<String, dynamic>> rows) async {
    final done = <String>[];
    for (final r in rows) {
      final id = r['_id'] as String;
      if (!_seen.add(id)) continue;
      done.add(id);
      if (_closed) continue;
      final from = r['fromDeviceId'] as String?;
      final kind = r['kind'] as String;
      if (_peerDevice != null && from != null && from != _peerDevice) continue;
      Object? payload;
      try {
        payload = jsonDecode(r['payload'] as String);
      } catch (_) {
        continue;
      }
      try {
        switch (kind) {
          case 'offer' when !offerer && _pc == null:
            _peerDevice ??= from;
            final pc = await _createPc();
            final m = payload as Map;
            await pc.setRemoteDescription(RTCSessionDescription(m['sdp'] as String?, m['type'] as String?));
            _remoteSet = true;
            await _drainRemoteIce();
            final answer = await pc.createAnswer({});
            await pc.setLocalDescription(answer);
            await _signal('answer', {'sdp': answer.sdp, 'type': answer.type});
          case 'answer' when offerer && !_remoteSet && _pc != null:
            _peerDevice ??= from;
            final m = payload as Map;
            await _pc!.setRemoteDescription(RTCSessionDescription(m['sdp'] as String?, m['type'] as String?));
            _remoteSet = true;
            await _drainRemoteIce();
          case 'ice':
            for (final c in (payload as List)) {
              final m = c as Map;
              _pendingRemoteIce.add(RTCIceCandidate(m['candidate'] as String?, m['sdpMid'] as String?, m['sdpMLineIndex'] as int?));
            }
            if (_remoteSet) await _drainRemoteIce();
          case 'bye':
            if (state.value == FightLinkState.connecting) _fail('peer left');
        }
      } catch (e) {
        debugPrint('FightLink: handling $kind failed: $e');
      }
    }
    if (done.isNotEmpty) {
      unawaited(_cv.mutation('fightSignals:consume', {'userId': userId, 'signalIds': done}).catchError((Object e) {
        debugPrint('FightLink: consume failed: $e');
        return null;
      }));
    }
  }

  Future<void> _drainRemoteIce() async {
    final pc = _pc;
    if (pc == null) return;
    final list = List.of(_pendingRemoteIce);
    _pendingRemoteIce.clear();
    for (final c in list) {
      try {
        await pc.addCandidate(c);
      } catch (e) {
        debugPrint('FightLink: addCandidate failed: $e');
      }
    }
  }

  void _flushIce() {
    _iceFlush = null;
    if (_iceOut.isEmpty || _closed) return;
    final batch = List.of(_iceOut);
    _iceOut.clear();
    unawaited(_signal('ice', batch));
  }

  Future<void> _signal(String kind, Object payload) async {
    try {
      await _cv.mutation('fightSignals:send', {
        'userId': userId,
        'matchId': matchId,
        'toUserId': peerUserId,
        'kind': kind,
        'payload': jsonEncode(payload),
        'fromDeviceId': deviceId,
      });
    } catch (e) {
      debugPrint('FightLink: send $kind failed: $e');
    }
  }

  void _fail(String why) {
    debugPrint('FightLink: failed ($why)');
    if (state.value == FightLinkState.connecting || state.value == FightLinkState.open) {
      state.value = FightLinkState.failed;
    }
  }

  bool get isOpen => state.value == FightLinkState.open;

  @override
  void sendInput(Uint8List bytes) {
    final ch = _fight;
    if (ch == null || ch.state != RTCDataChannelState.RTCDataChannelOpen) return;
    ch.send(RTCDataChannelMessage.fromBinary(bytes));
  }

  @override
  void sendControl(Map<String, dynamic> msg) {
    final ch = _ctl;
    if (ch == null || ch.state != RTCDataChannelState.RTCDataChannelOpen) return;
    ch.send(RTCDataChannelMessage(jsonEncode(msg)));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timeout?.cancel();
    _iceFlush?.cancel();
    sendControl({'t': 'bye'});
    if (state.value == FightLinkState.connecting) unawaited(_signal('bye', {}));
    _sub?.cancel();
    final pc = _pc;
    _pc = null;
    if (state.value != FightLinkState.failed) state.value = FightLinkState.closed;
    try {
      await _fight?.close();
      await _ctl?.close();
      await pc?.close();
      await pc?.dispose();
    } catch (_) {}
  }
}
