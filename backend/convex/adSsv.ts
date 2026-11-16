/**
 * AdMob rewarded-ad server-side verification (SSV).
 *
 * When a player finishes a rewarded ad, Google calls
 * `GET <site>/admob/ssv?ad_network=..&ad_unit=..&...&signature=..&key_id=..`.
 * Everything before `&signature=` is the signed message, the signature is a
 * websafe-base64 DER ECDSA P-256 / SHA-256 signature, and `key_id` names one
 * of Google's public keys (`VERIFIER_KEYS_URL`). Only a call that verifies AND
 * names one of our own ad units credits a banana: another publisher could
 * point their ad unit's SSV URL here, and their callbacks are signed by Google
 * too.
 *
 * No `import` from a Node-only module: this runs in the default Convex runtime
 * (Web Crypto).
 */

export const VERIFIER_KEYS_URL =
  "https://www.gstatic.com/admob/reward/verifier-keys.json";

/** Our rewarded ad units (the number after the slash): iOS, Android. */
export const DEFAULT_AD_UNITS = ["2127467203", "7852622518"];

export function allowedAdUnits(): Set<string> {
  const env = (globalThis as any).process?.env?.ADMOB_AD_UNITS as
    | string
    | undefined;
  const list = env ? env.split(",").map((s) => s.trim()) : DEFAULT_AD_UNITS;
  return new Set(list.filter(Boolean));
}

export type SsvParams = {
  message: string;
  signature: string;
  keyId: string;
  adUnit: string;
  userId: string;
  transactionId: string;
};

/** Splits the raw query string. Null when a required part is missing. */
export function parseSsv(rawQuery: string): SsvParams | null {
  const q = rawQuery.startsWith("?") ? rawQuery.slice(1) : rawQuery;
  const at = q.indexOf("&signature=");
  if (at < 0) return null;
  const message = q.slice(0, at);
  const params = new URLSearchParams(q);
  const signature = params.get("signature");
  const keyId = params.get("key_id");
  const adUnit = params.get("ad_unit");
  const userId = params.get("user_id");
  const transactionId = params.get("transaction_id");
  // AdMob's own "Verify URL" test call carries no user id (and may carry no
  // transaction id): still a signed call to answer 200, just nothing to credit.
  if (!signature || !keyId || !adUnit) return null;
  return {
    message,
    signature,
    keyId,
    adUnit,
    userId: userId ?? "",
    transactionId: transactionId ?? "",
  };
}

function b64ToBytes(b64: string): Uint8Array {
  const std = b64.replace(/-/g, "+").replace(/_/g, "/");
  const padded = std + "=".repeat((4 - (std.length % 4)) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** DER `SEQUENCE { INTEGER r, INTEGER s }` → raw 64-byte r||s for Web Crypto. */
export function derToRaw(der: Uint8Array): Uint8Array | null {
  let i = 0;
  if (der[i++] !== 0x30) return null;
  let len = der[i++];
  if (len & 0x80) i += len & 0x7f;
  const read = (): Uint8Array | null => {
    if (der[i++] !== 0x02) return null;
    const n = der[i++];
    let v = der.slice(i, i + n);
    i += n;
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    if (v.length > 32) return null;
    const out = new Uint8Array(32);
    out.set(v, 32 - v.length);
    return out;
  };
  const r = read();
  const s = read();
  if (!r || !s) return null;
  const raw = new Uint8Array(64);
  raw.set(r, 0);
  raw.set(s, 32);
  return raw;
}

let keyCache: { at: number; keys: Map<string, CryptoKey> } | null = null;

async function verifierKeys(): Promise<Map<string, CryptoKey>> {
  if (keyCache && Date.now() - keyCache.at < 6 * 3600_000) return keyCache.keys;
  const res = await fetch(VERIFIER_KEYS_URL);
  if (!res.ok) throw new Error(`keys ${res.status}`);
  const body: any = await res.json();
  const keys = new Map<string, CryptoKey>();
  for (const k of body.keys ?? []) {
    const key = await crypto.subtle.importKey(
      "spki",
      b64ToBytes(k.base64) as BufferSource,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"],
    );
    keys.set(String(k.keyId), key);
  }
  keyCache = { at: Date.now(), keys };
  return keys;
}

/** True when [p]'s signature verifies against Google's key [p.keyId]. */
export async function verifySsv(p: SsvParams): Promise<boolean> {
  let keys = await verifierKeys();
  if (!keys.has(p.keyId)) {
    // Google rotated: refetch once.
    keyCache = null;
    keys = await verifierKeys();
  }
  const key = keys.get(p.keyId);
  if (!key) return false;
  const raw = derToRaw(b64ToBytes(p.signature));
  if (!raw) return false;
  return await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    raw as BufferSource,
    new TextEncoder().encode(p.message),
  );
}
