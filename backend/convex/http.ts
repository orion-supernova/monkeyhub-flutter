/**
 * HTTP endpoints.
 *
 * Two of them. `/receipts/delivered` is documented at its route. The first
 * exists because of a property of this
 * deployment: `ctx.storage.getUrl` here returns `<site>/api/storage/<uuid>`
 * with no signature and no expiry (lib/media/file_url_cache.dart documents
 * this and caches URLs across launches on the strength of it). A URL like that
 * is equivalent to the file itself, forever — which is fine for an avatar and
 * fatal for a photo whose whole promise is that it can be looked at once.
 *
 * So view-once bytes are never addressed by storage URL. `messages:openViewOnce`
 * mints a short-lived, single-purpose nonce, and this route trades that nonce
 * for the bytes. Scraping the request out of a browser's network tab gets you a
 * URL that stops working two minutes later.
 */

import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { verifyReceipt, verifyRing } from "./receiptToken";

const http = httpRouter();

/**
 * The web build is served from a different origin than the Convex HTTP actions
 * endpoint (see hosting/caddy-monkeyhub.conf — the app lives at
 * monkeyhub.walhallaa.com/web/), so without these headers every fetch from the
 * web client fails in the browser before it reaches us.
 */
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

/**
 * The Content-Type to serve a view-once blob with.
 *
 * Convex keeps whatever type the uploader's PUT declared, and on a storage
 * stream that is the only container signal a player gets (the URL has no
 * extension; see `voiceNoteContentType` in lib/screens/voice_recorder_screen.dart
 * for what that cost voice notes on iOS). So the stored type is used when it
 * belongs to the message's own family, and a family default when it is
 * missing or does not: an `audio` message is never served as `text/html`
 * from this origin just because the sender's client said so.
 *
 * The defaults are what current clients upload: `audio/mp4` for a voice
 * message, `video/mp4` for a video or video note, JPEG for a photo.
 */
export function viewOnceContentType(messageType: string, stored: string): string {
  const family =
    messageType === "audio"
      ? "audio/"
      : messageType === "video" || messageType === "videoNote"
        ? "video/"
        : messageType === "image"
          ? "image/"
          : null;
  const fallback =
    family === "audio/"
      ? "audio/mp4"
      : family === "video/"
        ? "video/mp4"
        : family === "image/"
          ? "image/jpeg"
          : "application/octet-stream";
  const type = (stored ?? "").trim().toLowerCase();
  if (family !== null && type.startsWith(family)) return type;
  return fallback;
}

http.route({
  path: "/viewOnce",
  method: "OPTIONS",
  handler: httpAction(async () => new Response(null, { status: 204, headers: corsHeaders })),
});

http.route({
  path: "/viewOnce",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const url = new URL(request.url);
    const messageId = url.searchParams.get("m");
    const userId = url.searchParams.get("u");
    const nonce = url.searchParams.get("n");

    // One rejection shape for every failure — a bad nonce, an expired nonce,
    // someone else's nonce, and an already-burned photo are deliberately
    // indistinguishable from outside. Telling them apart would let a caller
    // probe which message ids are live view-once photos.
    const deny = () =>
      new Response("forbidden", { status: 403, headers: corsHeaders });

    if (!messageId || !userId || !nonce) return deny();

    let grant;
    try {
      grant = await ctx.runQuery(internal.messages.resolveViewOnceGrant, {
        messageId: messageId as any,
        userId: userId as any,
        nonce,
      });
    } catch (_) {
      // Malformed ids throw inside the validator rather than returning null.
      return deny();
    }
    if (!grant) return deny();

    const blob = await ctx.storage.get(grant.storageId);
    if (!blob) return deny();

    // Always the whole file, as one 200. A `Range` header is ignored rather
    // than honoured, and `Accept-Ranges: none` says so up front: a streaming
    // player handed this URL would otherwise issue a probe and then a run of
    // partial reads, each one a fresh fetch of a ticket that is meant to be
    // spent once. The contract for audio and video is the same as for a
    // photo: fetch the bytes once, into memory, and play from there.
    return new Response(blob, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": viewOnceContentType(grant.type, blob.type),
        "Accept-Ranges": "none",
        // The type above is chosen, not sniffed; keep it that way.
        "X-Content-Type-Options": "nosniff",
        // Nothing about this may be written down. A cache entry anywhere
        // between here and the decoder is a second viewing.
        "Cache-Control": "no-store, no-cache, must-revalidate, private",
        "Content-Disposition": "inline",
      },
    });
  }),
});

/**
 * A recipient's phone saying a message push arrived — the second tick, from
 * the notification extension (iOS), the push handler (Android) or the service
 * worker (web), with the app possibly not running at all. The body echoes the
 * fields the push carried; the signature over them is the whole of the
 * authentication. See receiptToken.ts.
 *
 * Answers 204 to anything well-formed whose signature checks out, whether or
 * not it moved the cursor, and 403 otherwise. The caller is a process that is
 * about to exit and will not retry either way.
 */
const receiptCors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

http.route({
  path: "/receipts/delivered",
  method: "OPTIONS",
  handler: httpAction(async () => new Response(null, { status: 204, headers: receiptCors })),
});

http.route({
  path: "/receipts/delivered",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const deny = () =>
      new Response("forbidden", { status: 403, headers: receiptCors });
    let body: any;
    try {
      body = await request.json();
    } catch {
      return deny();
    }
    const { roomId, userId, createdAt, sig } = body ?? {};
    if (
      typeof roomId !== "string" ||
      typeof userId !== "string" ||
      typeof createdAt !== "string" ||
      typeof sig !== "string"
    ) {
      return deny();
    }
    const upTo = Number(createdAt);
    if (!Number.isFinite(upTo)) return deny();
    if (!(await verifyReceipt(roomId, userId, createdAt, sig))) return deny();
    try {
      await ctx.runMutation(internal.messages.markDeliveredByPush, {
        roomId: roomId as any,
        userId: userId as any,
        upTo,
      });
    } catch (e) {
      // Signed by us, so the ids were real when the push left. A room or
      // account deleted since is the only way here; nothing to tell anyone.
      console.warn(`receipts/delivered: ${(e as Error).message}`);
    }
    return new Response(null, { status: 204, headers: receiptCors });
  }),
});

/**
 * A callee's phone has the ringer up — the ring proof from the VoIP push
 * (receiptToken.ts `ringFields`), posted by AppDelegate.swift's PushKit
 * handler or CallFcmService.kt once the card is on screen. 403 for a bad
 * signature; otherwise 200 with `{status}`, the call's status ("gone" once
 * the row is GC'd, "unknown" if it could not be read), which the iPhone uses
 * to end a card raised for a call that is already over. `probe: true` reads
 * the status without reporting a ring (the iPhone's native ring watch).
 * The poster never retries.
 */
http.route({
  path: "/calls/ringing",
  method: "OPTIONS",
  handler: httpAction(async () => new Response(null, { status: 204, headers: receiptCors })),
});

http.route({
  path: "/calls/ringing",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const deny = () =>
      new Response("forbidden", { status: 403, headers: receiptCors });
    let body: any;
    try {
      body = await request.json();
    } catch {
      return deny();
    }
    const { callId, userId, sig, probe } = body ?? {};
    if (
      typeof callId !== "string" ||
      typeof userId !== "string" ||
      typeof sig !== "string"
    ) {
      return deny();
    }
    if (!(await verifyRing(callId, userId, sig))) return deny();
    // The call's status rides back to the phone — see
    // `calls.markRingingInternal`. "unknown" when we could not read it: the
    // phone treats only a definite terminal answer as a reason to end a card.
    let status: string = "unknown";
    try {
      const read: string | null =
        probe === true
          ? await ctx.runQuery(internal.calls.ringStatusInternal, {
              callId: callId as any,
              userId: userId as any,
            })
          : await ctx.runMutation(internal.calls.markRingingInternal, {
              callId: callId as any,
              userId: userId as any,
            });
      status = read ?? "gone";
    } catch (e) {
      console.warn(`calls/ringing: ${(e as Error).message}`);
    }
    return new Response(JSON.stringify({ status }), {
      status: 200,
      headers: { ...receiptCors, "Content-Type": "application/json" },
    });
  }),
});

export default http;
