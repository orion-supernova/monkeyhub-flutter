// Production-shaped rollback netcode over the deterministic fight core.
// Pure Dart: the transport is a `send(Uint8List)` callback plus `receive()`.
//
// Model (GGPO style):
//  - A local input pressed at sim frame f applies at frame f + inputDelay.
//    Frames 0..inputDelay-1 are zero for both players (both sides know it).
//  - Remote input for a frame we have not heard of is predicted by repeating
//    the last contiguously confirmed remote input.
//  - Every simulated frame keeps a snapshot of the state before it. When a
//    late packet contradicts a prediction we restore the oldest wrong frame
//    and re-simulate up to the present.
//  - We never run more than [maxRollback] frames ahead of confirmed remote
//    input, and never put a new local input more than 8 frames ahead of what
//    the peer acknowledged (so an 8-input packet always covers the gap).
//  - Packets carry up to the last 8 local inputs, an ack of the remote inputs
//    we hold, our sim frame (time sync) and the latest confirmed checksum.

import 'dart:typed_data';

import '../core/fight_state.dart';
import '../core/fight_step.dart';

typedef DesyncCallback = void Function(int frame, int localChecksum, int remoteChecksum);

enum TickResult {
  /// One frame was simulated.
  advanced,

  /// Too far ahead of confirmed remote input (or the peer's ack): waiting.
  stalled,

  /// We are ahead of the peer's clock by more than [RollbackSession.maxFramesAhead]:
  /// the caller should skip this fixed update so the peer can catch up.
  skipped,
}

/// Wire packet. Layout (big endian):
///   u8 magic 0xF1 | u8 count | u32 frame | u32 ack+1 | u32 startFrame |
///   u32 csFrame+1 | u32 csValue | count x u16 input
class InputPacket {
  static const int magic = 0xF1;
  static const int maxInputs = 8;

  final int frame; // sender's sim frame
  final int ack; // highest contiguous frame of the receiver's inputs the sender holds (-1 none)
  final int startFrame;
  final List<int> inputs;
  final int csFrame; // -1 = none
  final int csValue;

  const InputPacket({
    required this.frame,
    required this.ack,
    required this.startFrame,
    required this.inputs,
    this.csFrame = -1,
    this.csValue = 0,
  });

  Uint8List encode() {
    final out = Uint8List(22 + 2 * inputs.length);
    var o = 0;
    out[o++] = magic;
    out[o++] = inputs.length;
    o = _put32(out, o, frame);
    o = _put32(out, o, ack + 1);
    o = _put32(out, o, startFrame);
    o = _put32(out, o, csFrame + 1);
    o = _put32(out, o, csValue);
    for (final i in inputs) {
      out[o++] = (i ~/ 256) % 256;
      out[o++] = i % 256;
    }
    return Uint8List.sublistView(out, 0, o);
  }

  /// Returns null for anything malformed.
  static InputPacket? decode(Uint8List b) {
    if (b.length < 22 || b[0] != magic) return null;
    final n = b[1];
    if (n > maxInputs || b.length != 22 + 2 * n) return null;
    final frame = _get32(b, 2);
    final ack = _get32(b, 6) - 1;
    final start = _get32(b, 10);
    final csFrame = _get32(b, 14) - 1;
    final csValue = _get32(b, 18);
    final inputs = <int>[];
    for (var k = 0; k < n; k++) {
      inputs.add(b[22 + 2 * k] * 256 + b[23 + 2 * k]);
    }
    return InputPacket(frame: frame, ack: ack, startFrame: start, inputs: inputs, csFrame: csFrame, csValue: csValue);
  }

  static int _put32(Uint8List b, int o, int v) {
    final u = v % 4294967296;
    b[o] = (u ~/ 16777216) % 256;
    b[o + 1] = (u ~/ 65536) % 256;
    b[o + 2] = (u ~/ 256) % 256;
    b[o + 3] = u % 256;
    return o + 4;
  }

  static int _get32(Uint8List b, int o) => b[o] * 16777216 + b[o + 1] * 65536 + b[o + 2] * 256 + b[o + 3];
}

class RollbackSession {
  final int localIndex;
  final int inputDelay;
  final int maxRollback;
  final int checksumInterval;
  final int maxFramesAhead;
  final void Function(Uint8List) send;
  final DesyncCallback? onDesync;

  FightState state;

  final Map<int, int> _local = {}; // frame -> local input applying at that frame
  final Map<int, int> _remote = {}; // frame -> confirmed remote input
  final Map<int, int> _used = {}; // frame -> remote input used when simulating it
  final Map<int, FightState> _snaps = {}; // frame -> state before simulating it
  final Map<int, int> _localCs = {};
  final Map<int, int> _remoteCs = {};

  int _remoteConfirmed; // highest contiguous frame with a known remote input
  int _peerAck; // highest contiguous frame of OUR inputs the peer reports holding
  int _rollbackFrom = -1;
  int _nextCsFrame;
  int _latestCsFrame = -1, _latestCs = 0;
  int _advantage = 0;
  bool desynced = false;

  // Stats.
  int rollbacks = 0, resimulated = 0, maxRollbackSeen = 0, stalls = 0, skips = 0;

  RollbackSession({
    required this.localIndex,
    required FightState initial,
    required this.send,
    this.inputDelay = 2,
    this.maxRollback = 8,
    this.checksumInterval = 30,
    this.maxFramesAhead = 3,
    this.onDesync,
  })  : state = initial,
        _remoteConfirmed = inputDelay - 1,
        _peerAck = inputDelay - 1,
        _nextCsFrame = checksumInterval {
    for (var f = 0; f < inputDelay; f++) {
      _local[f] = 0;
      _remote[f] = 0;
    }
  }

  /// Number of frames whose inputs are fully known (safe to treat as final).
  int get confirmedFrame => _remoteConfirmed + 1;

  /// Frames we run ahead of the peer's clock (positive = we should slow down).
  int get framesAhead => _advantage;

  int get pendingRollbackFrom => _rollbackFrom;

  int _predict() => _remote[_remoteConfirmed] ?? 0;

  int _remoteFor(int f) => _remote[f] ?? _predict();

  void _stepFrame(int f) {
    final li = _local[f] ?? 0;
    final ri = _remoteFor(f);
    _used[f] = ri;
    if (localIndex == 0) {
      step(state, li, ri);
    } else {
      step(state, ri, li);
    }
  }

  /// Applies any pending rollback. Called by [tick]; also exposed so tests and
  /// callers can settle the state without advancing.
  void flush() {
    if (_rollbackFrom < 0) return;
    final target = state.frame;
    final from = _rollbackFrom;
    _rollbackFrom = -1;
    final snap = _snaps[from];
    if (snap == null) return; // cannot happen while the stall rules hold
    state = snap.copy();
    for (var f = from; f < target; f++) {
      _snaps[f] = state.copy();
      _stepFrame(f);
    }
    rollbacks++;
    resimulated += target - from;
    if (target - from > maxRollbackSeen) maxRollbackSeen = target - from;
    _checkChecksums();
  }

  /// Re-sends the latest packet and settles pending rollbacks without
  /// advancing; call it instead of [tick] while waiting (e.g. after the match
  /// ended locally but the peer may still be missing our last inputs).
  void pump() {
    flush();
    _sendPacket();
  }

  TickResult tick(int localInput) {
    flush();
    final cur = state.frame;
    final newHi = cur + inputDelay;
    TickResult result;
    if (cur - (_remoteConfirmed + 1) >= maxRollback || newHi - _peerAck > InputPacket.maxInputs) {
      stalls++;
      result = TickResult.stalled;
    } else if (_advantage > maxFramesAhead) {
      skips++;
      _advantage--; // decay until the next packet refreshes the estimate
      result = TickResult.skipped;
    } else {
      _local[newHi] = localInput & 0x1FF;
      _snaps[cur] = state.copy();
      _stepFrame(cur);
      result = TickResult.advanced;
      _checkChecksums();
    }
    _sendPacket();
    _prune();
    return result;
  }

  void _sendPacket() {
    var hi = state.frame + inputDelay - 1;
    while (_local.containsKey(hi + 1)) {
      hi++;
    }
    final lo = hi - InputPacket.maxInputs + 1 < 0 ? 0 : hi - InputPacket.maxInputs + 1;
    final ins = <int>[for (var f = lo; f <= hi; f++) _local[f] ?? 0];
    send(InputPacket(
      frame: state.frame,
      ack: _remoteConfirmed,
      startFrame: lo,
      inputs: ins,
      csFrame: _latestCsFrame,
      csValue: _latestCs,
    ).encode());
  }

  void receive(Uint8List data) {
    final pk = InputPacket.decode(data);
    if (pk == null) return;
    final floor = state.frame - 48;
    for (var k = 0; k < pk.inputs.length; k++) {
      final f = pk.startFrame + k;
      if (f < floor || _remote.containsKey(f)) continue;
      final v = pk.inputs[k] & 0x1FF;
      _remote[f] = v;
      final used = _used[f];
      if (used != null && used != v && (_rollbackFrom < 0 || f < _rollbackFrom)) _rollbackFrom = f;
    }
    while (_remote.containsKey(_remoteConfirmed + 1)) {
      _remoteConfirmed++;
    }
    if (pk.ack > _peerAck) _peerAck = pk.ack;
    // Time sync: estimate the peer's clock now from its frame, our ack echo.
    final rttFrames = state.frame - (pk.ack - inputDelay);
    final oneWay = rttFrames > 0 ? rttFrames ~/ 2 : 0;
    _advantage = state.frame - (pk.frame + oneWay);
    if (pk.csFrame >= 0) {
      _remoteCs[pk.csFrame] = pk.csValue;
      _compare(pk.csFrame);
    }
  }

  void _checkChecksums() {
    while (_nextCsFrame <= state.frame &&
        _remoteConfirmed >= _nextCsFrame - 1 &&
        (_rollbackFrom < 0 || _rollbackFrom >= _nextCsFrame)) {
      final st = _nextCsFrame == state.frame ? state : _snaps[_nextCsFrame];
      if (st == null) {
        _nextCsFrame += checksumInterval;
        continue;
      }
      final cs = st.checksum();
      _localCs[_nextCsFrame] = cs;
      _latestCsFrame = _nextCsFrame;
      _latestCs = cs;
      _compare(_nextCsFrame);
      _nextCsFrame += checksumInterval;
    }
  }

  void _compare(int frame) {
    final l = _localCs[frame];
    final r = _remoteCs[frame];
    if (l == null || r == null || l == r || desynced) return;
    desynced = true;
    onDesync?.call(frame, l, r);
  }

  void _prune() {
    final cut = state.frame - 48;
    if (cut <= 0) return;
    for (final m in [_local, _remote, _used, _snaps, _localCs, _remoteCs]) {
      m.remove(cut);
      m.remove(cut - 1);
    }
  }
}
