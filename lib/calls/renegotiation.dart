import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// The pieces of mid-call renegotiation that do not care whether the call is
/// a pair or a mesh.
///
/// Both call services follow one rule: only the designated offerer ever
/// creates an offer (the caller in 1:1, the lower userId in a mesh), so an
/// offer can never meet another offer on the wire. That rule was cheap while
/// a link's tracks were fixed at setup; it costs something now that a
/// camera can come on in a voice call and a screen can join a video call.
/// The answering side of a link cannot offer, so when it wants to send a new
/// track it adds the track locally — unified plan lets a track sit on an
/// unassociated transceiver — and asks the offerer, with a `renegotiate`
/// signal, to re-offer with enough video sections to carry it. The offerer
/// then adds receive-only sections until it has as many as the peer asked
/// for and sends a `reoffer`; the answerer's waiting transceivers attach to
/// those sections in order and its `reanswer` completes the exchange.
///
/// **Slots, not tracks.** Each side has at most two outbound video slots per
/// link — its camera and its screen — and a slot is negotiated ONCE: the
/// first time it is used, its track is added and the link renegotiated;
/// after that the slot is switched on and off with `replaceTrack`, which
/// needs no signaling at all. Nothing ever calls `removeTrack`: a sender
/// that has sent can never be reused by `addTrack`, so tearing a slot down
/// would leave the answering side unable to bring it back without a section
/// the offerer does not know to offer.
///
/// This file holds the transceiver arithmetic; the state machine (who is
/// negotiating, what is queued behind it, which sequence number an answer
/// must echo) lives per link in the services, next to the generation guards
/// it has to respect.

/// How many video sections the connection currently has, whatever their
/// direction.
Future<int> countVideoTransceivers(RTCPeerConnection pc) async {
  try {
    final ts = await pc.getTransceivers();
    return ts.where(_isVideo).length;
  } catch (e) {
    debugPrint('countVideoTransceivers failed: $e');
    return 0;
  }
}

/// Adds receive-only video sections until the connection has at least
/// [wanted]. Called by the offerer before it re-offers, so the peer's
/// pending tracks have somewhere to land.
Future<void> ensureRecvVideoSlots(RTCPeerConnection pc, int wanted) async {
  var have = await countVideoTransceivers(pc);
  while (have < wanted) {
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    have++;
  }
}

/// Whether a local video track is sitting on a section the last exchange
/// did not cover — the answerer's cue to ask for another round.
Future<bool> hasUnassociatedVideoSender(RTCPeerConnection pc) async {
  try {
    final ts = await pc.getTransceivers();
    for (final t in ts) {
      if (t.sender.track?.kind == 'video' && t.mid.isEmpty) return true;
    }
  } catch (e) {
    debugPrint('hasUnassociatedVideoSender failed: $e');
  }
  return false;
}

bool _isVideo(RTCRtpTransceiver t) {
  final recv = t.receiver.track?.kind;
  if (recv != null) return recv == 'video';
  return t.sender.track?.kind == 'video';
}

/// Sequence-numbered offer/answer bookkeeping for one link.
///
/// A plain object the services embed per peer. It answers two questions —
/// "may I offer now?" and "is this the answer I am waiting for?" — and
/// remembers that somebody wanted another round while one was in flight.
class LinkNegotiation {
  /// An offer of ours is out and unanswered. Set for the initial offer and
  /// for ICE-restart offers too: those are offers, and a re-offer sent on
  /// top of one would answer a section list the peer never saw.
  bool inFlight = false;

  /// A slot changed while [inFlight]; run again when the answer lands.
  bool dirty = false;

  /// Sequence of the last `reoffer` sent; a `reanswer` must echo it. An
  /// answer to a superseded offer — one an ICE restart overtook — is dropped
  /// on this rather than applied to the wrong local description.
  int seq = 0;

  /// The most video sections the peer has asked for, ever. Kept across
  /// rebuilds: a fresh link to the same peer needs the same room.
  int wantedVideoSlots = 0;

  /// Marks an offer as sent. Returns the sequence it was tagged with.
  int begin() {
    inFlight = true;
    dirty = false;
    return ++seq;
  }

  /// Whether an inbound answer tagged [answerSeq] is the one in flight.
  /// Untagged answers (the initial `answer`, a `restart-answer`) are always
  /// current — nothing else can be outstanding at the same time.
  bool accepts(int? answerSeq) => answerSeq == null || answerSeq == seq;

  /// The answer landed. Returns true when another round was queued.
  bool finish() {
    inFlight = false;
    final again = dirty;
    dirty = false;
    return again;
  }

  /// A rebuilt link starts from nothing but [wantedVideoSlots].
  void reset() {
    inFlight = false;
    dirty = false;
  }
}
