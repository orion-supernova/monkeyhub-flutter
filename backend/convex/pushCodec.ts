// Encoding and signing primitives shared by the push transports.
//
// Deliberately contains NO Convex function definitions and touches no `ctx`.
// That is what lets `webPush.ts` — which must run in the Node runtime, because
// Convex's V8 isolate does not implement `crypto.subtle.deriveBits` for ECDH —
// import the same code as the V8-runtime senders instead of duplicating it.

/**
 * A byte string backed by a plain `ArrayBuffer`.
 *
 * TypeScript 5.7 made `Uint8Array` generic over its backing buffer, and a bare
 * `Uint8Array` now means `Uint8Array<ArrayBufferLike>` — which INCLUDES
 * `SharedArrayBuffer`, and is therefore not a valid `BufferSource` or
 * `BodyInit`. Every `crypto.subtle` call and every `fetch` body in this module
 * and in `webPush.ts` was rejected on that basis, for code that has been
 * delivering push notifications in production the whole time.
 *
 * The narrowing is accurate rather than a silencing cast: every value typed
 * `Bytes` here is freshly allocated — `new Uint8Array(n)`, `TextEncoder.encode`,
 * or a view over an `ArrayBuffer` that `crypto.subtle` just returned. None of
 * them can be a `SharedArrayBuffer` view, because nothing in this backend ever
 * creates one.
 *
 * Used on the boundaries — parameters and return types — so the inference
 * flows through the call graph on its own.
 */
export type Bytes = Uint8Array<ArrayBuffer>;

export async function signJwt(
  header: Record<string, unknown>,
  claims: Record<string, unknown>,
  privateKeyPem: string,
  alg: "ES256" | "RS256",
): Promise<string> {
  const enc = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;
  const der = pemToDer(privateKeyPem);
  const importAlg:
    | AlgorithmIdentifier
    | EcKeyImportParams
    | RsaHashedImportParams =
    alg === "ES256"
      ? { name: "ECDSA", namedCurve: "P-256" }
      : { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" };
  const signAlg: AlgorithmIdentifier | EcdsaParams =
    alg === "ES256"
      ? { name: "ECDSA", hash: "SHA-256" }
      : { name: "RSASSA-PKCS1-v1_5" };
  const key = await crypto.subtle.importKey("pkcs8", der, importAlg, false, [
    "sign",
  ]);
  const sig = await crypto.subtle.sign(
    signAlg,
    key,
    new TextEncoder().encode(enc),
  );
  return `${enc}.${b64url(new Uint8Array(sig))}`;
}

export function b64url(input: string | Bytes): string {
  let bytes: Bytes;
  if (typeof input === "string") {
    bytes = new TextEncoder().encode(input);
  } else {
    bytes = input;
  }
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

/** Inverse of [b64url]. Also accepts standard base64 (browsers send both). */
export function b64urlToBytes(input: string): Bytes {
  const b64 = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function pemToDer(pem: string): Bytes {
  const b64 = pem
    .replace(/-----BEGIN [A-Z ]+-----/g, "")
    .replace(/-----END [A-Z ]+-----/g, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
