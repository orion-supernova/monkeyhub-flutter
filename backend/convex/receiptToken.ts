/**
 * Delivery proof that the recipient's phone can send back without signing in.
 *
 * The second tick used to need the app open: only the running app's room-list
 * subscription called `markRoomDelivered`, so a message whose push had already
 * buzzed a locked phone still read "waiting" to its sender until the app was
 * launched. The code that does run on arrival — the iOS notification
 * extension and Android's FirebaseMessagingService — has no Convex session,
 * and giving it one would mean sharing a long-lived credential with a process
 * that runs for every push.
 *
 * So the push carries its own proof. `sendAlert` signs (room, recipient,
 * message time) with a server secret and puts the signature, and the URL to
 * post it to, in that recipient's payload. The phone echoes the fields back;
 * `/receipts/delivered` (http.ts) checks the signature and moves the cursor.
 * Nothing about it is a secret on the device: the token can only ever say
 * "this person's phone got the push for this message", which is exactly what
 * the phone holding it is in a position to say. Replaying it is a no-op.
 *
 * Off — no fields added, the app-open path alone — until `RECEIPT_SECRET` is
 * set on the deployment. Both backends should carry the same value, so a token
 * minted by one is still good if the other takes the post.
 */

const enc = new TextEncoder();

function secret(): string | null {
  const s = (process.env.RECEIPT_SECRET ?? "").trim();
  return s.length > 0 ? s : null;
}

function message(roomId: string, userId: string, createdAt: string): string {
  return `${roomId}|${userId}|${createdAt}`;
}

async function key(s: string, usage: "sign" | "verify"): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    enc.encode(s),
    { name: "HMAC", hash: "SHA-256" },
    false,
    [usage],
  );
}

function toBase64Url(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.byteLength; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(s: string): Uint8Array<ArrayBuffer> | null {
  try {
    const b64 = s.replace(/-/g, "+").replace(/_/g, "/");
    const bin = atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4));
    const out = new Uint8Array(new ArrayBuffer(bin.length));
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  } catch {
    return null;
  }
}

/**
 * Where the phone posts the proof: this deployment's HTTP actions.
 *
 * Not `CONVEX_SITE_URL`. On the self-hosted boxes both origins are the same
 * hostname and HTTP actions answer under `/http` on it (see
 * hosting/ampere/convex-compose.yml) — the bare origin 404s. A Convex cloud
 * deployment serves them at the root of its `.convex.site` twin instead.
 * `RECEIPT_URL` overrides both, for a host laid out some third way.
 */
export function receiptEndpoint(): string | null {
  const explicit = (process.env.RECEIPT_URL ?? "").trim();
  if (explicit) return explicit;
  const cloud = (process.env.CONVEX_CLOUD_URL ?? "").trim().replace(/\/+$/, "");
  if (!cloud) return null;
  try {
    const url = new URL(cloud);
    if (url.hostname.endsWith(".convex.cloud")) {
      url.hostname = url.hostname.replace(/\.convex\.cloud$/, ".convex.site");
      return `${url.origin}/receipts/delivered`;
    }
  } catch {
    return null;
  }
  return `${cloud}/http/receipts/delivered`;
}

/**
 * The payload fields for one recipient of one message push, or null when the
 * feature is off. Keys are a cross-language contract with
 * NotificationService.swift, CallFcmService.kt and web/mh-push-sw.js — see
 * test/push_payload_contract_test.dart.
 */
export async function receiptFields(
  roomId: string,
  userId: string,
  createdAt: string,
): Promise<Record<string, string> | null> {
  const s = secret();
  const url = receiptEndpoint();
  if (!s || !url) return null;
  const sig = await crypto.subtle.sign(
    "HMAC",
    await key(s, "sign"),
    enc.encode(message(roomId, userId, createdAt)),
  );
  return {
    rcptUrl: url,
    rcptUser: userId,
    rcptSig: toBase64Url(new Uint8Array(sig)),
  };
}

/** Whether [sig] is this deployment's signature over the three fields. */
export async function verifyReceipt(
  roomId: string,
  userId: string,
  createdAt: string,
  sig: string,
): Promise<boolean> {
  const s = secret();
  const bytes = fromBase64Url(sig);
  if (!s || !bytes) return false;
  // `verify` rather than comparing strings: it is constant-time.
  return await crypto.subtle.verify(
    "HMAC",
    await key(s, "verify"),
    bytes,
    enc.encode(message(roomId, userId, createdAt)),
  );
}
