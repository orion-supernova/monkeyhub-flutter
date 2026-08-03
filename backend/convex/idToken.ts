/**
 * Verification of Apple / Google OpenID Connect ID tokens.
 *
 * This is the whole reason social sign-in works on a self-hosted deployment: no
 * part of it asks Convex for an identity. `ctx.auth` is never consulted, there
 * is no auth.config.ts, and no JWT ever reaches the client. The provider signs a
 * token, we check the signature ourselves inside an action, and the caller gets
 * back the same `userId` the rest of the backend already trusts.
 *
 * Runs in the DEFAULT V8 runtime — no `"use node"`. `voipPush.ts` already signs
 * APNs/FCM JWTs with `crypto.subtle` here in production, and `fetch` to external
 * hosts is likewise already exercised, so nothing below is new ground for the
 * deployment.
 *
 * `jose` rather than a hand-rolled verifier on purpose. The two ways to get this
 * wrong — reading `alg` off the token you are trying to authenticate, and
 * botching base64url — are exactly the two things a library removes. Convex's
 * own @convex-dev/auth runs jose inside a mutation, so it is known to work in
 * this runtime.
 */

import { internalAction } from "./_generated/server";
import { v } from "convex/values";
import { verifyAppleCredentials } from "./appleTokens";
import {
  createRemoteJWKSet,
  jwtVerify,
  SignJWT,
  generateKeyPair,
  type JWTPayload,
} from "jose";

export type Provider = "apple" | "google";

export const PROVIDER_APPLE = "apple";
export const PROVIDER_GOOGLE = "google";

/** Opaque to the client on purpose — see `verifyIdToken`. */
export const ERR_TOKEN_INVALID = "SOCIAL_TOKEN_INVALID";
export const ERR_NONCE_MISMATCH = "SOCIAL_NONCE_MISMATCH";
export const ERR_MISCONFIG = "SOCIAL_MISCONFIG";

const APPLE_ISSUER = "https://appleid.apple.com";

/**
 * Google signs `iss` as either form and it genuinely varies between tokens, so
 * both must be accepted. Apple only ever uses the one.
 */
const GOOGLE_ISSUERS = ["accounts.google.com", "https://accounts.google.com"];

const JWKS_URLS: Record<Provider, string> = {
  apple: "https://appleid.apple.com/auth/keys",
  google: "https://www.googleapis.com/oauth2/v3/certs",
};

/**
 * Module-scope so a warm isolate reuses the fetched key set, and so `kid`
 * rotation is handled by jose rather than by us. Convex recycles isolates
 * freely, so treat this as best-effort: a cold isolate simply refetches, which
 * costs one HTTPS round trip on the first sign-in it serves.
 */
const keySets: Partial<Record<Provider, ReturnType<typeof createRemoteJWKSet>>> = {};

function keySet(provider: Provider) {
  return (keySets[provider] ??= createRemoteJWKSet(new URL(JWKS_URLS[provider])));
}

/**
 * The allow-list the token's `aud` must land in, from deployment env.
 *
 * Never derived from the token. `aud` is the only thing stopping an ID token
 * minted for somebody else's app — which is a perfectly valid, correctly signed
 * Apple/Google token — from being replayed here as a login.
 *
 * Apple native: the iOS bundle id. Google: set `serverClientId` on both
 * platforms so this stays a single web client id rather than one per platform.
 */
function audiencesFor(provider: Provider): string[] {
  const raw =
    provider === PROVIDER_APPLE
      ? process.env.APPLE_BUNDLE_ID
      : process.env.GOOGLE_CLIENT_IDS;
  const list = (raw ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (list.length === 0) {
    throw new Error(
      `${ERR_MISCONFIG}: ${provider === PROVIDER_APPLE ? "APPLE_BUNDLE_ID" : "GOOGLE_CLIENT_IDS"} is not set`,
    );
  }
  return list;
}

export interface VerifiedIdentity {
  provider: Provider;
  /** The provider's stable subject. The ONLY thing we key an account on. */
  subject: string;
  email?: string;
  emailVerified: boolean;
  /** Apple's `@privaterelay.appleid.com` addresses. */
  isPrivateRelay: boolean;
}

/** Apple sends these as the STRINGS "true"/"false"; Google sends real booleans. */
const truthy = (v: unknown): boolean => v === true || v === "true";

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Verifies signature, issuer, audience and expiry, then the nonce binding.
 *
 * Throws an OPAQUE error on any failure. The real reason is logged, never
 * returned: the difference between "expired", "wrong audience" and "bad
 * signature" is useful to an attacker probing the endpoint and useless to a
 * legitimate client, which can only ever retry the whole flow anyway.
 */
export async function verifyIdToken(
  provider: Provider,
  idToken: string,
  rawNonce: string | undefined,
): Promise<VerifiedIdentity> {
  let payload: JWTPayload;
  try {
    ({ payload } = await jwtVerify(idToken, keySet(provider), {
      // PINNED. Never let the token nominate its own algorithm — that is the
      // alg-confusion bug (alg:"none", or HS256 verified against the public key
      // as if it were a shared secret).
      algorithms: ["RS256"],
      issuer: provider === PROVIDER_APPLE ? APPLE_ISSUER : GOOGLE_ISSUERS,
      audience: audiencesFor(provider),
      clockTolerance: 60,
    }));
  } catch (err) {
    // Worth reading carefully when this fires: Convex's WebCrypto is stricter
    // than a browser's — subtle_crypto enforces that the JWK's own `alg`
    // matches and that `use === "sig"`. Both Apple and Google publish
    // alg:"RS256" + use:"sig", so this passes in practice, but a mismatch
    // surfaces as a DataError from importKey that reads nothing like a failed
    // signature check.
    console.error(`[idToken] ${provider} verify failed:`, err);
    throw new Error(ERR_TOKEN_INVALID);
  }

  const subject = typeof payload.sub === "string" ? payload.sub : "";
  if (subject.length === 0) {
    console.error(`[idToken] ${provider} token has no sub`);
    throw new Error(ERR_TOKEN_INVALID);
  }

  // Nonce binding, formulated so it cannot be skipped by simply omitting
  // `rawNonce`: if the provider echoed a nonce, the caller MUST produce the
  // preimage. Only a token that carries no nonce at all is exempt.
  const nonceClaim = payload.nonce;
  if (typeof nonceClaim === "string" && nonceClaim.length > 0) {
    if (rawNonce === undefined) {
      console.error(`[idToken] ${provider} token carries a nonce but none was supplied`);
      throw new Error(ERR_NONCE_MISMATCH);
    }
    if (nonceClaim !== (await sha256Hex(rawNonce))) {
      console.error(`[idToken] ${provider} nonce mismatch`);
      throw new Error(ERR_NONCE_MISMATCH);
    }
  }

  const email = typeof payload.email === "string" ? payload.email : undefined;
  return {
    provider,
    subject,
    email,
    emailVerified: truthy(payload.email_verified),
    isPrivateRelay: truthy(payload.is_private_email),
  };
}

/**
 * One-command health check: `npx convex run idToken:selfTest`.
 *
 * Internal because it is diagnostics, not product surface. Covers the three
 * things that can be broken independently of each other and that all present as
 * "sign-in doesn't work":
 *   1. jose bundles and round-trips through this runtime at all
 *   2. the deployment can actually reach Apple's and Google's JWKS endpoints
 *      (the one thing a restrictive outbound firewall would take away)
 *   3. the audience env vars are set
 */
export const selfTest = internalAction({
  args: {},
  returns: v.record(v.string(), v.string()),
  handler: async (): Promise<Record<string, string>> => {
    const results: Record<string, string> = {};
    const msg = (e: unknown) => (e instanceof Error ? e.message : String(e));

    try {
      const { privateKey, publicKey } = await generateKeyPair("RS256");
      const token = await new SignJWT({ nonce: "n" })
        .setProtectedHeader({ alg: "RS256" })
        .setIssuer("https://selftest.invalid")
        .setAudience("selftest-aud")
        .setSubject("selftest-sub")
        .setIssuedAt()
        .setExpirationTime("5m")
        .sign(privateKey);

      const { payload } = await jwtVerify(token, publicKey, {
        algorithms: ["RS256"],
        issuer: "https://selftest.invalid",
        audience: "selftest-aud",
      });
      results.joseRoundTrip = payload.sub === "selftest-sub" ? "OK" : "WRONG_SUB";

      // A tampered token must be REJECTED. A verifier that accepts everything
      // would pass the check above just as happily.
      try {
        await jwtVerify(`${token}x`, publicKey, { algorithms: ["RS256"] });
        results.joseRejectsTampered = "FAIL — tampered token was accepted";
      } catch {
        results.joseRejectsTampered = "OK";
      }
    } catch (e) {
      results.joseRoundTrip = `FAIL ${msg(e)}`;
    }

    for (const provider of [PROVIDER_APPLE, PROVIDER_GOOGLE] as Provider[]) {
      try {
        const res = await fetch(JWKS_URLS[provider]);
        const body = (await res.json()) as { keys?: unknown[] };
        results[`jwks_${provider}`] =
          res.ok && Array.isArray(body.keys) && body.keys.length > 0
            ? `OK (${body.keys.length} keys)`
            : `FAIL http ${res.status}`;
      } catch (e) {
        results[`jwks_${provider}`] = `FAIL ${msg(e)}`;
      }

      try {
        results[`audience_${provider}`] = `OK (${audiencesFor(provider).length} configured)`;
      } catch (e) {
        results[`audience_${provider}`] = msg(e);
      }
    }

    // Not just "is it set" — actually asks Apple whether the credentials work.
    results.appleRevokeCredentials = await verifyAppleCredentials();

    return results;
  },
});
