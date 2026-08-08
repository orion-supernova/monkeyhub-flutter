"use node";

import { internalAction } from "./_generated/server";
import { v } from "convex/values";
import { b64url, b64urlToBytes, signJwt } from "./pushCodec";

// Web Push, spoken directly to whatever push service the browser handed us
// (fcm.googleapis.com for Chrome, updates.push.services.mozilla.com for
// Firefox, web.push.apple.com for Safari). No SDK, no vendor.
//
// Three RFCs stacked on top of each other:
//   RFC 8030  the HTTP protocol — POST to the endpoint, TTL/Urgency/Topic
//   RFC 8188  the `aes128gcm` content coding — the salt/rs/keyid framing
//   RFC 8291  how a push payload derives its key from the subscription
//   RFC 8292  VAPID — the ES256 JWT that identifies us to the push service
//
// ── Why this file alone says "use node" ──────────────────────────────────
//
// Convex's default V8 isolate implements only part of WebCrypto, and the
// missing part is exactly the one RFC 8291 is built on:
//
//     Not implemented: crypto.subtle.deriveBits for ECDH.
//
// APNs and FCM get away with the V8 runtime because they only ever *sign*
// (ECDSA/RSA), which is implemented. Web Push has to agree a shared secret
// with the browser, and there is no way to do that without ECDH. So this is a
// Node action, reached from `push.ts` over `ctx.runAction` rather than by a
// direct import — a V8 module that imported this file would drag the Node
// runtime into its own bundle.
//
// The cost is a slower cold start on the web path only. Rewriting P-256 scalar
// multiplication in pure JS to stay in V8 would be far worse.
//
// This is the only hand-rolled cryptography in the codebase, and its failure
// mode is a silent HTTP 400 with no diagnostic — a wrong info string or a
// misplaced delimiter byte produces bytes the browser simply refuses. That is
// what `selfTest` below is for: run it after any change here.
//
// Required Convex env vars:
//   VAPID_PUBLIC_KEY      base64url, raw uncompressed P-256 point (65 bytes)
//   VAPID_PRIVATE_KEY_P8  PKCS#8 PEM for the matching private key
//   VAPID_SUBJECT         "mailto:…" or "https://…" contact for the operator

/** Record size. We only ever send one record, so this is just the framing. */
const RECORD_SIZE = 4096;

/**
 * Push services guarantee at least 4096 octets of encrypted payload. The
 * framing overhead is fixed (16 salt + 4 rs + 1 idlen + 65 key + 16 GCM tag +
 * 1 delimiter), so this is what's left for JSON.
 */
const MAX_WEB_PUSH_PLAINTEXT = 4096 - 16 - 4 - 1 - 65 - 16 - 1;

/** VAPID JWTs may live 24h; 12 sits comfortably inside every service's limit. */
const VAPID_TTL_SECONDS = 12 * 60 * 60;

/**
 * Deliver one payload to one browser subscription.
 *
 * Returns a result rather than throwing, because the caller lives in another
 * runtime: a thrown error crossing `ctx.runAction` arrives wrapped, and the
 * three-class error prefix the caller branches on would no longer be at the
 * start of the message.
 */
export const sendOne = internalAction({
  args: {
    endpoint: v.string(),
    p256dh: v.string(),
    auth: v.string(),
    /** Flat string map; becomes the JSON body the service worker reads. */
    payload: v.any(),
    ttlSeconds: v.number(),
    urgency: v.string(),
    topic: v.optional(v.string()),
  },
  returns: v.object({
    ok: v.boolean(),
    error: v.optional(v.string()),
  }),
  handler: async (_ctx, args) => {
    const publicKey = process.env.VAPID_PUBLIC_KEY;
    const privateKeyPem = process.env.VAPID_PRIVATE_KEY_P8;
    const subject = process.env.VAPID_SUBJECT;
    if (!publicKey || !privateKeyPem || !subject) {
      return {
        ok: false,
        error:
          "WEBPUSH_MISCONFIG: missing VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY_P8 / VAPID_SUBJECT",
      };
    }

    let origin: string;
    try {
      const u = new URL(args.endpoint);
      origin = `${u.protocol}//${u.host}`;
    } catch {
      // A stored endpoint that won't parse can never be delivered to. Treat it
      // as dead so the sweep drops the subscription rather than retrying.
      return { ok: false, error: "WEBPUSH_BAD_TOKEN:0:unparseable endpoint" };
    }

    // Signed per push rather than cached. The APNs cache exists because Apple
    // rate-limits provider-token *updates*; no push service has that rule, and
    // one ECDSA signature is cheaper than the database round trip a cache costs.
    let jwt: string;
    try {
      jwt = await signJwt(
        { typ: "JWT", alg: "ES256" },
        {
          aud: origin,
          exp: Math.floor(Date.now() / 1000) + VAPID_TTL_SECONDS,
          sub: subject,
        },
        privateKeyPem,
        "ES256",
      );
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { ok: false, error: `WEBPUSH_MISCONFIG: VAPID signing (${msg})` };
    }

    const json = JSON.stringify(args.payload ?? {});
    if (json.length > MAX_WEB_PUSH_PLAINTEXT) {
      return {
        ok: false,
        error: `WEBPUSH_MISCONFIG: payload ${json.length} > ${MAX_WEB_PUSH_PLAINTEXT} bytes`,
      };
    }

    let body: Uint8Array;
    try {
      const asKeyPair = (await crypto.subtle.generateKey(
        { name: "ECDH", namedCurve: "P-256" },
        true,
        ["deriveBits"],
      )) as CryptoKeyPair;
      const salt = crypto.getRandomValues(new Uint8Array(16));
      body = await encryptPayload(
        json,
        b64urlToBytes(args.p256dh),
        b64urlToBytes(args.auth),
        salt,
        asKeyPair,
      );
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { ok: false, error: `WEBPUSH_MISCONFIG: encryption (${msg})` };
    }

    const headers: Record<string, string> = {
      // RFC 8292 §3: the token and the public key that verifies it.
      authorization: `vapid t=${jwt}, k=${publicKey}`,
      "content-encoding": "aes128gcm",
      "content-type": "application/octet-stream",
      ttl: String(args.ttlSeconds),
      urgency: args.urgency,
    };
    // RFC 8030 §5.4: base64url alphabet, 32 chars max. Convex ids qualify, but
    // truncate rather than let a longer key become a 400.
    if (args.topic) headers.topic = args.topic.slice(0, 32);

    let res: Response;
    try {
      res = await fetch(args.endpoint, { method: "POST", headers, body });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { ok: false, error: `WEBPUSH_TRANSIENT: ${msg}` };
    }
    if (res.ok) return { ok: true };
    return { ok: false, error: classify(res.status, await res.text()) };
  },
});

function classify(status: number, body: string): string {
  // Same three-class split as APNs and FCM, so the caller's error branch is
  // identical for all three transports.
  //   404/410 → the subscription is gone (user cleared site data, unsubscribed,
  //             or the browser expired it). Delete it.
  //   400/401/403/413 → our request is wrong (bad VAPID, bad encryption, too
  //             big). NEVER delete — the subscription is fine, we aren't.
  //   429/5xx → push service blip. Keep it and retry.
  if (status === 404 || status === 410) {
    return `WEBPUSH_BAD_TOKEN:${status}:${body}`;
  }
  if (status === 400 || status === 401 || status === 403 || status === 413) {
    return `WEBPUSH_MISCONFIG: HTTP ${status}: ${body}`;
  }
  if (status === 429 || status >= 500) {
    return `WEBPUSH_TRANSIENT: HTTP ${status}: ${body}`;
  }
  return `WebPush HTTP ${status}: ${body}`;
}

// ────────────────────────── RFC 8291 / RFC 8188 ──────────────────────────

/**
 * Encrypt one `aes128gcm` record for [uaPublic]/[authSecret].
 *
 * [salt] and [asKeyPair] are parameters rather than generated in here so that
 * `selfTest` can pin them to the RFC 8291 §5 vector. Production callers pass
 * fresh random values — reusing either across two pushes to the same
 * subscription would reuse an AES-GCM key/nonce pair, which is catastrophic.
 */
async function encryptPayload(
  plaintextJson: string,
  uaPublic: Uint8Array,
  authSecret: Uint8Array,
  salt: Uint8Array,
  asKeyPair: CryptoKeyPair,
): Promise<Uint8Array> {
  const asPublic = new Uint8Array(
    await crypto.subtle.exportKey("raw", asKeyPair.publicKey),
  );

  // Public ECDH keys import with NO usages — passing ["deriveBits"] here is
  // rejected, which is a surprisingly common way to get stuck.
  const uaKey = await crypto.subtle.importKey(
    "raw",
    uaPublic,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  const ecdhSecret = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "ECDH", public: uaKey },
      asKeyPair.privateKey,
      256,
    ),
  );

  // RFC 8291 §3.4. Each of these is one HKDF (extract THEN expand), which is
  // exactly what a single deriveBits({name:"HKDF"}) call performs — the
  // intermediate PRKs in the RFC's pseudocode never need to be materialised.
  const keyInfo = concat(
    utf8("WebPush: info"),
    Uint8Array.of(0),
    uaPublic,
    asPublic,
  );
  const ikm = await hkdf(authSecret, ecdhSecret, keyInfo, 32);
  const cek = await hkdf(salt, ikm, utf8z("Content-Encoding: aes128gcm"), 16);
  const nonce = await hkdf(salt, ikm, utf8z("Content-Encoding: nonce"), 12);

  // RFC 8188 §2: every record's plaintext ends in a delimiter — 0x01 for a
  // record with more to follow, 0x02 for the last one. We always send exactly
  // one record, so it is always 0x02.
  const plaintext = concat(utf8(plaintextJson), Uint8Array.of(2));
  const aesKey = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, [
    "encrypt",
  ]);
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: "AES-GCM", iv: nonce, tagLength: 128 },
      aesKey,
      plaintext,
    ),
  );

  // RFC 8188 §2.1 header: salt(16) | rs(4, big-endian) | idlen(1) | keyid.
  // Our keyid is the ephemeral sender public key, which is how the browser
  // completes the same ECDH from its side.
  const header = new Uint8Array(16 + 4 + 1 + asPublic.length);
  header.set(salt, 0);
  new DataView(header.buffer).setUint32(16, RECORD_SIZE, false);
  header[20] = asPublic.length;
  header.set(asPublic, 21);
  return concat(header, ciphertext);
}

async function hkdf(
  salt: Uint8Array,
  ikm: Uint8Array,
  info: Uint8Array,
  lengthBytes: number,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", ikm, "HKDF", false, [
    "deriveBits",
  ]);
  const bits = await crypto.subtle.deriveBits(
    { name: "HKDF", hash: "SHA-256", salt, info },
    key,
    lengthBytes * 8,
  );
  return new Uint8Array(bits);
}

function utf8(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}

/** The RFC's info strings are all NUL-terminated. */
function utf8z(s: string): Uint8Array {
  return concat(utf8(s), Uint8Array.of(0));
}

function concat(...parts: Uint8Array[]): Uint8Array {
  let n = 0;
  for (const p of parts) n += p.length;
  const out = new Uint8Array(n);
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}

// ────────────────────────── self-test ──────────────────────────

// The published example from RFC 8291 §5. Keys and salt are fixed so the
// output is deterministic and comparable byte-for-byte.
const RFC8291_PLAINTEXT = "When I grow up, I want to be a watermelon";
const RFC8291_UA_PUBLIC =
  "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4";
const RFC8291_UA_PRIVATE = "q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94";
const RFC8291_AUTH = "BTBZMqHH6r4Tts7J_aSIgg";
const RFC8291_AS_PUBLIC =
  "BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8";
const RFC8291_AS_PRIVATE = "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw";
const RFC8291_SALT = "DGv6ra1nlYgDCS1FRnbzlw";
const RFC8291_EXPECTED =
  "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN";

/**
 * Prove the encryption is correct without needing a browser.
 *
 * Run after ANY edit to this file:
 *   npx convex run webPush:selfTest
 *
 * Two independent checks, reported separately on purpose:
 *
 *   roundTrip  encrypt, then decrypt with the receiver's private key and
 *              compare the plaintext. Catches framing, delimiter and AES-GCM
 *              mistakes. It cannot catch a wrong HKDF info string, because
 *              both directions would be wrong in the same way.
 *
 *   matchesRfc byte-for-byte against the published vector. This is the check
 *              that pins the info strings and the key-derivation order.
 *
 * If roundTrip passes and matchesRfc fails, suspect the constants above (they
 * are transcribed by hand) before suspecting the algorithm.
 */
export const selfTest = internalAction({
  args: {},
  handler: async () => {
    const uaPublic = b64urlToBytes(RFC8291_UA_PUBLIC);
    const authSecret = b64urlToBytes(RFC8291_AUTH);
    const salt = b64urlToBytes(RFC8291_SALT);
    const asKeyPair = await importEcdhKeyPair(
      RFC8291_AS_PRIVATE,
      RFC8291_AS_PUBLIC,
    );

    const body = await encryptPayload(
      RFC8291_PLAINTEXT,
      uaPublic,
      authSecret,
      salt,
      asKeyPair,
    );
    const actual = b64url(body);

    let roundTrip = false;
    let roundTripError = "";
    try {
      const uaKeyPair = await importEcdhKeyPair(
        RFC8291_UA_PRIVATE,
        RFC8291_UA_PUBLIC,
      );
      const decrypted = await decryptForTest(
        body,
        uaKeyPair.privateKey,
        uaPublic,
        authSecret,
      );
      roundTrip = decrypted === RFC8291_PLAINTEXT;
      if (!roundTrip) {
        roundTripError = `decrypted to ${JSON.stringify(decrypted)}`;
      }
    } catch (e) {
      roundTripError = e instanceof Error ? e.message : String(e);
    }

    const matchesRfc = actual === RFC8291_EXPECTED;
    const result = { roundTrip, roundTripError, matchesRfc, actual };
    if (roundTrip && matchesRfc) {
      console.log("webPush.selfTest: PASS — RFC 8291 §5 vector reproduced");
    } else {
      console.error(`webPush.selfTest: FAIL ${JSON.stringify(result)}`);
    }
    return result;
  },
});

/**
 * Import a raw P-256 scalar + point pair as a CryptoKeyPair.
 *
 * WebCrypto has no "raw" import for private keys, so the 32-byte `d` is
 * rebuilt into a JWK alongside the x/y halves of the uncompressed public
 * point (which is `0x04 || x || y`). Test-only.
 */
async function importEcdhKeyPair(
  privateB64: string,
  publicB64: string,
): Promise<CryptoKeyPair> {
  const pub = b64urlToBytes(publicB64);
  const jwk = {
    kty: "EC",
    crv: "P-256",
    d: privateB64,
    x: b64url(pub.slice(1, 33)),
    y: b64url(pub.slice(33, 65)),
    ext: true,
  };
  const privateKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "ECDH", namedCurve: "P-256" },
    true,
    ["deriveBits"],
  );
  const publicKey = await crypto.subtle.importKey(
    "raw",
    pub,
    { name: "ECDH", namedCurve: "P-256" },
    true,
    [],
  );
  return { privateKey, publicKey };
}

/** The receiver's half of RFC 8291, so the self-test can verify a round trip. */
async function decryptForTest(
  body: Uint8Array,
  uaPrivate: CryptoKey,
  uaPublic: Uint8Array,
  authSecret: Uint8Array,
): Promise<string> {
  const salt = body.slice(0, 16);
  const idlen = body[20];
  const asPublic = body.slice(21, 21 + idlen);
  const ciphertext = body.slice(21 + idlen);

  const asKey = await crypto.subtle.importKey(
    "raw",
    asPublic,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  const ecdhSecret = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "ECDH", public: asKey },
      uaPrivate,
      256,
    ),
  );
  const keyInfo = concat(
    utf8("WebPush: info"),
    Uint8Array.of(0),
    uaPublic,
    asPublic,
  );
  const ikm = await hkdf(authSecret, ecdhSecret, keyInfo, 32);
  const cek = await hkdf(salt, ikm, utf8z("Content-Encoding: aes128gcm"), 16);
  const nonce = await hkdf(salt, ikm, utf8z("Content-Encoding: nonce"), 12);
  const aesKey = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, [
    "decrypt",
  ]);
  const plain = new Uint8Array(
    await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: nonce, tagLength: 128 },
      aesKey,
      ciphertext,
    ),
  );
  // Strip the trailing record delimiter.
  return new TextDecoder().decode(plain.slice(0, plain.length - 1));
}
