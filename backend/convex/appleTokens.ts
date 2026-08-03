/**
 * Apple's token endpoints — exchanging an authorization code for a refresh
 * token, and revoking that token when an account is deleted.
 *
 * This exists because App Store guideline 5.1.1(v) and TN3194 require that
 * deleting an account also revokes the Sign in with Apple grant. Revocation
 * needs a refresh token, and a refresh token can only be obtained by exchanging
 * an authorization code — which is why `socialAuth.signIn` bothers to accept one
 * at all.
 *
 * Every function here is BEST-EFFORT and returns null/false rather than
 * throwing. Two deliberate consequences:
 *   - sign-in keeps working before the Apple key is configured, so the feature
 *     can ship ahead of the developer-portal work;
 *   - account deletion is never blocked by Apple being unreachable. A user who
 *     cannot delete their account is a worse guideline problem than a grant that
 *     outlived its account, so we log loudly and proceed.
 *
 * Credentials live in Convex deployment env vars (`npx convex env set`), exactly
 * like APNS_KEY_P8 — never in `env.local`, which is bundled into the shipped app.
 */

import { SignJWT, importPKCS8 } from "jose";

const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";

/**
 * Apple allows up to six months, but these calls happen twice in an account's
 * lifetime (first sign-in, deletion), so there is nothing to amortise and a
 * short-lived secret is strictly safer. Contrast `voipPush.cachedProviderToken`,
 * where APNs *requires* reuse across ~50 minutes.
 */
const CLIENT_SECRET_TTL = "5m";

interface AppleConfig {
  keyP8: string;
  keyId: string;
  teamId: string;
  clientId: string;
}

/**
 * Null when Sign in with Apple revocation has not been configured yet. Reuses
 * APNS_TEAM_ID because it is the same developer team — but the .p8 is a
 * SEPARATE key from the APNs one; they are not interchangeable.
 */
function appleConfig(): AppleConfig | null {
  const keyP8 = process.env.APPLE_SIWA_KEY_P8;
  const keyId = process.env.APPLE_SIWA_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const clientId = process.env.APPLE_BUNDLE_ID;
  if (!keyP8 || !keyId || !teamId || !clientId) return null;
  return { keyP8, keyId, teamId, clientId };
}

/**
 * The ES256 assertion Apple wants in place of a client secret.
 *
 * `sub` is the client id (our bundle id for the native flow), `iss` is the team
 * id — they are not the same thing and swapping them yields an opaque
 * `invalid_client`.
 */
async function clientSecret(cfg: AppleConfig): Promise<string> {
  const key = await importPKCS8(cfg.keyP8, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: cfg.keyId })
    .setIssuer(cfg.teamId)
    .setAudience("https://appleid.apple.com")
    .setSubject(cfg.clientId)
    .setIssuedAt()
    .setExpirationTime(CLIENT_SECRET_TTL)
    .sign(key);
}

async function postForm(
  url: string,
  fields: Record<string, string>,
): Promise<Response> {
  return await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(fields).toString(),
  });
}

/**
 * Authorization code → refresh token. Null if unconfigured or Apple refused.
 *
 * The code is single-use and expires in five minutes, so this is called inline
 * during sign-in rather than deferred to a scheduled job.
 */
export async function exchangeAuthorizationCode(
  code: string,
): Promise<string | null> {
  const cfg = appleConfig();
  if (!cfg) {
    console.warn(
      "[appleTokens] APPLE_SIWA_KEY_P8/APPLE_SIWA_KEY_ID unset — skipping refresh-token capture. " +
        "Sign-in still works; revocation on delete will not.",
    );
    return null;
  }
  try {
    const res = await postForm(APPLE_TOKEN_URL, {
      client_id: cfg.clientId,
      client_secret: await clientSecret(cfg),
      grant_type: "authorization_code",
      code,
    });
    if (!res.ok) {
      console.error(`[appleTokens] code exchange HTTP ${res.status}: ${await res.text()}`);
      return null;
    }
    const body = (await res.json()) as { refresh_token?: string };
    if (!body.refresh_token) {
      console.error("[appleTokens] code exchange returned no refresh_token");
      return null;
    }
    return body.refresh_token;
  } catch (err) {
    console.error("[appleTokens] code exchange threw:", err);
    return null;
  }
}

/**
 * Revokes the grant. Returns whether Apple confirmed it.
 *
 * Callers MUST NOT block account deletion on a false return — log and continue.
 */
export async function revokeRefreshToken(refreshToken: string): Promise<boolean> {
  const cfg = appleConfig();
  if (!cfg) {
    console.error(
      "[appleTokens] cannot revoke — Apple SIWA key not configured. " +
        "This account's Apple grant will outlive its account.",
    );
    return false;
  }
  try {
    const res = await postForm(APPLE_REVOKE_URL, {
      client_id: cfg.clientId,
      client_secret: await clientSecret(cfg),
      token: refreshToken,
      token_type_hint: "refresh_token",
    });
    // Apple answers 200 with an empty body on success.
    if (!res.ok) {
      console.error(`[appleTokens] revoke HTTP ${res.status}: ${await res.text()}`);
      return false;
    }
    return true;
  } catch (err) {
    console.error("[appleTokens] revoke threw:", err);
    return false;
  }
}

/**
 * End-to-end check of the Apple credential chain, for `idToken.selfTest`.
 *
 * Worth having because every part of this can be individually wrong in a way
 * that is silent until someone deletes their account — a `.p8` that didn't
 * survive being pasted into an env var, a Key ID from a different key, a key
 * that was never configured for this App ID.
 *
 * The trick is that Apple distinguishes the two failures for us. We deliberately
 * present a garbage refresh token:
 *   `invalid_grant`  → our client secret was ACCEPTED; only the dummy token was
 *                      rejected, which is exactly what we want to see.
 *   `invalid_client` → the credentials themselves are wrong.
 */
export async function verifyAppleCredentials(): Promise<string> {
  const cfg = appleConfig();
  if (!cfg) {
    return "not configured — sign-in still works, revocation does not";
  }

  let secret: string;
  try {
    secret = await clientSecret(cfg);
  } catch (err) {
    return `FAIL — the .p8 did not import or sign (${err instanceof Error ? err.message : String(err)})`;
  }

  try {
    const res = await postForm(APPLE_TOKEN_URL, {
      client_id: cfg.clientId,
      client_secret: secret,
      grant_type: "refresh_token",
      refresh_token: "selftest.deliberately.invalid",
    });
    const body = await res.text();
    if (body.includes("invalid_client")) {
      return "FAIL — Apple rejected our credentials (invalid_client). Check APPLE_SIWA_KEY_ID matches the .p8, APNS_TEAM_ID is the team that owns it, APPLE_BUNDLE_ID is right, and the key is configured for that App ID.";
    }
    if (body.includes("invalid_grant")) {
      return "OK — Apple accepted the client secret and rejected only the dummy token, as expected";
    }
    return `unexpected: HTTP ${res.status} ${body.slice(0, 160)}`;
  } catch (err) {
    return `FAIL — ${err instanceof Error ? err.message : String(err)}`;
  }
}

/**
 * Confirms a stored refresh token is still valid. Used by the daily cron TN3194
 * asks for — a token Apple has already invalidated (user revoked us from their
 * Apple ID settings) means the grant is gone and the row can stop pretending it
 * can revoke.
 */
export async function refreshTokenStillValid(
  refreshToken: string,
): Promise<boolean | null> {
  const cfg = appleConfig();
  if (!cfg) return null;
  try {
    const res = await postForm(APPLE_TOKEN_URL, {
      client_id: cfg.clientId,
      client_secret: await clientSecret(cfg),
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    });
    if (res.ok) return true;
    // 400 invalid_grant is the definitive "this grant is gone". Anything else
    // (5xx, network) is inconclusive and must not be treated as revoked.
    if (res.status === 400) return false;
    console.error(`[appleTokens] refresh check HTTP ${res.status}`);
    return null;
  } catch (err) {
    console.error("[appleTokens] refresh check threw:", err);
    return null;
  }
}
