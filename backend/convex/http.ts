/**
 * HTTP endpoints.
 *
 * There is exactly one, and it exists because of a property of this
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

    return new Response(blob, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": blob.type || "application/octet-stream",
        // Nothing about this may be written down. A cache entry anywhere
        // between here and the decoder is a second viewing.
        "Cache-Control": "no-store, no-cache, must-revalidate, private",
        "Content-Disposition": "inline",
      },
    });
  }),
});

export default http;
