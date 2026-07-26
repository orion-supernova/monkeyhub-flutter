import '../models/chat_message.dart';
import '../models/enums.dart';

/// Deciding which optimistic bubbles the server has now confirmed.
///
/// Pulled out of `ChatRepository` as free functions so the rule can be pinned by
/// a test that needs no socket, no fake backend and no clock — which matters,
/// because the rule that used to live inline was wrong in a way no integration
/// test would ever have caught.
///
/// What was wrong: it asked `live.any(...)` and matched on
/// `(senderId, content, ±10 minutes)`. Every captionless photo has
/// `content == ''`, so a *single* incoming empty-content message from the same
/// sender satisfied the predicate for **every** pending empty-content message at
/// once and deleted all of them. With one photo in flight at a time that was a
/// rare, invisible bug. Now that a photo's bubble appears the moment SEND is
/// tapped and several can be uploading together, it would have eaten the lot.

/// Whether [live] is the server's copy of [pending].
///
/// Media is matched on the storage id whenever both sides have one: that id is
/// minted by the upload and referenced by exactly one message, so equality is a
/// real key and no time window is needed. Everything else falls back to content
/// plus a generous window — text, and view-once photos, whose storage id the
/// server strips from every read path so there is nothing to compare.
bool reconcilesWith(ChatMessage live, ChatMessage pending) {
  // Its bytes are still going up, so there is no server copy of it yet by
  // definition. Without this check a burst of photos would reconcile each other
  // away mid-upload on the strength of an unrelated echo.
  if (pending.status == MessageStatus.uploading) return false;

  // Best evidence: the server echoed the idempotency key this very bubble
  // minted, so the row names its own origin. Decisive in BOTH directions — a
  // row that carries someone else's key is not this bubble's, however alike the
  // two look. This is also the only signal that works when the ack is the thing
  // that went missing, because it arrives on the subscription rather than as
  // the mutation's return value.
  final echoed = live.clientId;
  if (echoed != null) return echoed == pending.id;

  // The send acked and told us exactly which row it created, so there is
  // nothing to infer. Reachable when the deployment predates `clientId`.
  final acked = pending.serverId;
  if (acked != null) return live.id == acked;

  // Neither key available: an old server and an unacked send. Infer.
  if (live.senderId != pending.senderId) return false;
  if (live.type != pending.type) return false;
  if (live.viewOnce != pending.viewOnce) return false;

  final liveId = live.mediaStorageId;
  final pendingId = pending.mediaStorageId;
  if (liveId != null && pendingId != null) return liveId == pendingId;

  if (live.content != pending.content) return false;
  // The window is generous on purpose, and the reason is unchanged from when it
  // was written: a metro-tunnel send where the server stored the message but the
  // ack never made it back gets marked `error` locally, and has to collapse into
  // a single bubble once reconnect finally delivers the live row.
  return live.createdAt.difference(pending.createdAt).inMinutes.abs() < 10;
}

/// The subset of [pending] the server has *not* confirmed, in order.
///
/// One-to-one: each live row claims at most one pending message. That is the
/// whole fix — `any` is what turned one echo into "drop all of them".
List<ChatMessage> survivingPending(
  List<ChatMessage> live,
  List<ChatMessage> pending,
) {
  if (pending.isEmpty) return const [];
  final claimed = List<bool>.filled(pending.length, false);
  for (final l in live) {
    for (var i = 0; i < pending.length; i++) {
      if (claimed[i]) continue;
      if (reconcilesWith(l, pending[i])) {
        claimed[i] = true;
        break;
      }
    }
  }
  final out = <ChatMessage>[];
  for (var i = 0; i < pending.length; i++) {
    if (!claimed[i]) out.add(pending[i]);
  }
  return out;
}
