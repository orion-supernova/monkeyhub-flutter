import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'draw_model.dart';
import 'draw_wire.dart';

/// The data channels a drawing rides on: one per peer, fanned out directly.
///
/// The mesh already has a peer connection to everyone in the call, so a
/// stroke goes to each of them over that link and nowhere else — no relay,
/// no server, no ordering across peers to reconcile. Each channel is owned
/// by its peer connection; this only remembers them and forgets them.
class DrawChannels {
  DrawChannels({required this.model}) {
    model.onOutbound = broadcast;
  }

  static const String label = 'draw';

  /// Ordered and reliable. A stroke is small and its points depend on each
  /// other; a dropped packet would leave a gap in the line, not save a frame.
  static RTCDataChannelInit init() => RTCDataChannelInit()
    ..ordered = true
    ..binaryType = 'binary';

  /// Past this much unsent data on a channel the peer is not keeping up;
  /// a stroke that arrives a second late is worse than one that never does.
  static const int maxBuffered = 64 * 1024;

  final DrawModel model;
  final Map<String, RTCDataChannel> _channels = {};

  Iterable<String> get peers => _channels.keys;

  void attach(String peerId, RTCDataChannel ch) {
    _channels[peerId] = ch;
    ch.onMessage = (msg) {
      if (!msg.isBinary) return;
      final ops = decodeDrawBatch(msg.binary);
      if (ops.isNotEmpty) model.apply(peerId, ops);
    };
  }

  void detach(String peerId) {
    final ch = _channels.remove(peerId);
    if (ch != null) ch.onMessage = null;
  }

  /// Sends [ops] to every open channel. Encoded once.
  void broadcast(List<DrawOp> ops) {
    if (ops.isEmpty || _channels.isEmpty) return;
    Uint8List? bytes;
    for (final entry in _channels.entries) {
      final ch = entry.value;
      if (ch.state != RTCDataChannelState.RTCDataChannelOpen) continue;
      if ((ch.bufferedAmount ?? 0) > maxBuffered) continue;
      bytes ??= encodeDrawBatch(ops);
      try {
        ch.send(RTCDataChannelMessage.fromBinary(bytes));
      } catch (e) {
        debugPrint('DrawChannels.broadcast(${entry.key}): $e');
      }
    }
  }

  void dispose() {
    for (final ch in _channels.values) {
      ch.onMessage = null;
    }
    _channels.clear();
    if (identical(model.onOutbound, broadcast)) model.onOutbound = null;
  }
}
