import { internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { signJwt } from "./pushCodec";

// Re-exported so the senders have one import site for the whole transport.
export { b64url, b64urlToBytes, pemToDer, signJwt } from "./pushCodec";

// Shared push transport: everything that speaks HTTP to Apple and Google, and
// nothing that knows what a notification means.
//
// Two senders sit on top of this file — `voipPush.ts` (PushKit / CallKit wake-
// ups) and `push.ts` (ordinary alert notifications) — plus `webPush.ts`, which
// borrows the JWT signer and the provider-token cache for VAPID. Keeping the
// transport in one place is what stops the alert path from re-deriving the
// APNs quirks the call path already learned the hard way.
//
// Runs in the DEFAULT V8 runtime — no `use node`. All crypto is WebCrypto.
//
// Required Convex env vars:
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_KEY_P8, APNS_SANDBOX
//   FCM_SERVICE_ACCOUNT_JSON

// ─────────────── push-provider auth token caching ───────────────
//
// APNs REQUIRES the same provider JWT be reused for 20-60 minutes. Signing
// a fresh one per push trips Apple's TooManyProviderTokenUpdates 429 rate
// limit, after which EVERY push for the key fails until the window cools —
// observed as "calling randomly dies completely under rapid testing, then
// recovers after a quiet period". Tokens are cached in module scope (fast
// path, per warm isolate) and in the pushAuthTokens table (survives cold
// starts and is shared across isolates). Google's FCM OAuth tokens get the
// same treatment (valid 60 min; per-push minting is needless latency), as do
// VAPID JWTs (one per push-service origin).
//
// NOTE: this cache now guards ALL push traffic, not just calls. A regression
// here is a total notification outage rather than a calls-only one — the
// 50-minute window and the keyRef rotation key are both load-bearing.

const TOKEN_REUSE_MS = 50 * 60 * 1000;

type ProviderTokenEntry = { token: string; keyRef: string; issuedAt: number };

const providerTokenCache: Record<string, ProviderTokenEntry> = {};

/// Mints currently in flight, keyed the same way as the cache above.
///
/// The cache has one hole, and a message fan-out falls straight into it: every
/// device is pushed concurrently (`push.sendAlert` → `Promise.allSettled` over
/// targets, then over each target's devices), and each one calls
/// [cachedProviderToken] independently. On a COLD isolate the module cache is
/// empty for all of them, so N devices meant N simultaneous mints — N Google
/// OAuth round trips at 1.3-1.5s each, and then N writes racing to patch the
/// same `pushAuthTokens` row. Convex answered that the only way it can: OCC
/// retries at 20-750ms, and thirteen mutations in a three-hour window that
/// exhausted their retries outright. On a two-core box that CPU is taken
/// straight out of whatever mutation a user is waiting on.
///
/// Latching the in-flight promise collapses the fan-out to ONE mint and one
/// write, which is what the cache always intended. Keyed by provider rather
/// than global because APNs, FCM and each VAPID origin mint independently and
/// have no reason to queue behind each other.
const providerTokenInFlight: Record<string, Promise<string>> = {};

export const _getPushAuthToken = internalQuery({
  args: { provider: v.string() },
  returns: v.union(
    v.null(),
    v.object({
      token: v.string(),
      keyRef: v.string(),
      issuedAt: v.number(),
    }),
  ),
  handler: async (ctx, { provider }) => {
    const row = await ctx.db
      .query("pushAuthTokens")
      .withIndex("by_provider", (q) => q.eq("provider", provider))
      .first();
    if (!row) return null;
    return { token: row.token, keyRef: row.keyRef, issuedAt: row.issuedAt };
  },
});

export const _setPushAuthToken = internalMutation({
  args: {
    provider: v.string(),
    token: v.string(),
    keyRef: v.string(),
    issuedAt: v.number(),
  },
  returns: v.null(),
  handler: async (ctx, { provider, token, keyRef, issuedAt }) => {
    const row = await ctx.db
      .query("pushAuthTokens")
      .withIndex("by_provider", (q) => q.eq("provider", provider))
      .first();
    if (row) {
      await ctx.db.patch(row._id, { token, keyRef, issuedAt });
    } else {
      await ctx.db.insert("pushAuthTokens", {
        provider,
        token,
        keyRef,
        issuedAt,
      });
    }
    return null;
  },
});

// Returns a provider auth token, minting a fresh one only when the cached
// one is missing, older than TOKEN_REUSE_MS, or signed with a different
// key (keyRef mismatch — key rotation). Concurrent refreshes across
// isolates are harmless: they happen at most once per ~50 min, far below
// any provider's update limit.
//
// `provider` is a free-form cache key rather than a closed union because
// VAPID needs one entry per push-service origin ("vapid:https://…"), and
// those origins are whatever the browsers hand us.
export async function cachedProviderToken(
  ctx: any,
  provider: string,
  keyRef: string,
  mint: () => Promise<string>,
): Promise<string> {
  const now = Date.now();
  const mem = providerTokenCache[provider];
  if (mem && mem.keyRef === keyRef && now - mem.issuedAt < TOKEN_REUSE_MS) {
    return mem.token;
  }
  const stored = (await ctx.runQuery(
    internal.pushTransport._getPushAuthToken,
    { provider },
  )) as ProviderTokenEntry | null;
  if (
    stored &&
    stored.keyRef === keyRef &&
    now - stored.issuedAt < TOKEN_REUSE_MS
  ) {
    providerTokenCache[provider] = stored;
    return stored.token;
  }
  // Someone else in this isolate is already minting this exact provider —
  // wait for theirs rather than starting a second one. See
  // [providerTokenInFlight].
  const pending = providerTokenInFlight[provider];
  if (pending) return await pending;

  const flight = (async () => {
    const token = await mint();
    const entry: ProviderTokenEntry = { token, keyRef, issuedAt: Date.now() };
    providerTokenCache[provider] = entry;
    await ctx.runMutation(internal.pushTransport._setPushAuthToken, {
      provider,
      ...entry,
    });
    return token;
  })();
  providerTokenInFlight[provider] = flight;
  try {
    return await flight;
  } finally {
    // Cleared on failure as well as success, or one failed mint would leave
    // every later push awaiting a promise that is never going to resolve.
    delete providerTokenInFlight[provider];
  }
}

// ────────────────────────── APNs ──────────────────────────

export type ApnsEnv = "sandbox" | "production";

export type ApnsRequest = {
  token: string;
  env?: ApnsEnv;
  // "" targets the ALERT topic (the bare bundle id); ".voip" targets PushKit.
  // These are two different tokens on two different topics — crossing them
  // gets a 400 DeviceTokenNotForTopic. See `push.ts` on why the alert sender
  // structurally cannot see a voipToken.
  topicSuffix: "" | ".voip";
  pushType: "alert" | "background" | "voip";
  priority: "10" | "5";
  // Absolute unix seconds. APNs holds the push for a briefly-unreachable
  // device until this moment instead of discarding it (0 = now-or-drop).
  expiration: number;
  // Sent as the `apns-collapse-id` HEADER, not a payload key. iOS uses it as
  // the UNNotificationRequest identifier, which is exactly what
  // removeDeliveredNotifications(withIdentifiers:) takes — the entire dismiss
  // path depends on this being set. 64-byte cap; a Convex id is 32 chars.
  collapseId?: string;
  body: Record<string, unknown>;
};

export async function apnsPost(ctx: any, req: ApnsRequest): Promise<void> {
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const bundleId = process.env.APNS_BUNDLE_ID;
  const keyP8 = process.env.APNS_KEY_P8;
  if (!keyId || !teamId || !bundleId || !keyP8) {
    throw new Error(
      "APNS_MISCONFIG: missing APNS_KEY_ID / APNS_TEAM_ID / APNS_BUNDLE_ID / APNS_KEY_P8",
    );
  }
  // Per-token environment wins (a sandbox token only works against the
  // sandbox host and vice-versa). Falls back to the APNS_SANDBOX env for
  // legacy rows registered before apnsEnv existed — defaulting to PRODUCTION
  // when the env var is absent, since that's where real users' tokens live
  // (a sandbox default would silently 400 every production token).
  const sandbox =
    req.env === "production"
      ? false
      : req.env === "sandbox"
        ? true
        : (process.env.APNS_SANDBOX ?? "false") === "true";

  // Cached provider JWT — reused for ~50 min per Apple's requirement.
  // NEVER mint per-push: that trips TooManyProviderTokenUpdates and takes
  // down every push for the key.
  let jwt: string;
  try {
    jwt = await cachedProviderToken(ctx, "apns", keyId, () =>
      signJwt(
        { alg: "ES256", typ: "JWT", kid: keyId },
        { iss: teamId, iat: Math.floor(Date.now() / 1000) },
        keyP8,
        "ES256",
      ),
    );
  } catch (e) {
    // A malformed/expired .p8 key fails here. This is a deployment
    // misconfiguration, not a bad device token — never clear the token.
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`APNS_MISCONFIG: JWT signing failed (${msg})`);
  }

  const host = sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const headers: Record<string, string> = {
    authorization: `bearer ${jwt}`,
    "apns-topic": `${bundleId}${req.topicSuffix}`,
    "apns-push-type": req.pushType,
    "apns-priority": req.priority,
    "apns-expiration": String(req.expiration),
    "content-type": "application/json",
  };
  if (req.collapseId) {
    headers["apns-collapse-id"] = req.collapseId.slice(0, 64);
  }

  const res = await fetch(`https://${host}/3/device/${req.token}`, {
    method: "POST",
    headers,
    body: JSON.stringify(req.body),
  });
  if (!res.ok) throw apnsError(res.status, await res.text());
}

// APNs answers a failure with `{"reason": "..."}`. Which of the three classes
// it lands in depends on that string, NOT on the status code alone.
//
// This distinction is the whole ballgame for the alert path. The VoIP-only
// version of this code mapped every 400 to BAD_TOKEN and cleared the token —
// survivable when one topic was in play, catastrophic now: a single wrong
// `apns-topic` returns 400 TopicDisallowed for EVERY device, and a blanket
// "clear the token" response would empty the token table within minutes and
// present as "push randomly stopped working for everyone".
const APNS_TOKEN_REASONS = new Set([
  "BadDeviceToken",
  "Unregistered",
  "ExpiredToken",
  // The token is real but belongs to a different topic — i.e. we crossed the
  // alert and PushKit columns. Clearing it is the safe response, but the real
  // fix is never to cross them; see push.ts `_loadAlertTargets`.
  "DeviceTokenNotForTopic",
]);

const APNS_CONFIG_REASONS = new Set([
  "TopicDisallowed",
  "BadTopic",
  "MissingTopic",
  "BadCollapseId",
  "BadExpirationDate",
  "BadPriority",
  "BadMessageId",
  "PayloadEmpty",
  "PayloadTooLarge",
  "InvalidProviderToken",
  "ExpiredProviderToken",
  "MissingProviderToken",
  "BadCertificate",
  "BadCertificateEnvironment",
  "Forbidden",
]);

function apnsError(status: number, body: string): Error {
  let reason = "";
  try {
    reason = ((JSON.parse(body) as { reason?: string }).reason ?? "").trim();
  } catch {
    // Non-JSON body (proxy error page, empty 5xx) — fall through to the
    // status-only classification below.
  }
  if (status === 410) return new Error(`APNS_BAD_TOKEN:410:${reason}`);
  if (status === 400) {
    if (APNS_TOKEN_REASONS.has(reason)) {
      return new Error(`APNS_BAD_TOKEN:400:${reason}`);
    }
    if (APNS_CONFIG_REASONS.has(reason)) {
      return new Error(`APNS_MISCONFIG: 400 ${reason}`);
    }
    // An unrecognised 400 is our payload bug far more often than it is a dead
    // token, and the cost of guessing wrong is asymmetric: a wrongly-kept
    // token retries next push, a wrongly-cleared one silences the device.
    return new Error(`APNS_MISCONFIG: 400 ${reason || body}`);
  }
  if (status === 401 || status === 403) {
    return new Error(`APNS_MISCONFIG: HTTP ${status}: ${body}`);
  }
  if (status === 429 || status >= 500) {
    return new Error(`APNS_TRANSIENT: HTTP ${status}: ${body}`);
  }
  return new Error(`APNs HTTP ${status}: ${body}`);
}

// ────────────────────────── FCM v1 ──────────────────────────

// Takes the complete `message` object so callers own the shape (data-only vs
// webpush config vs android ttl) rather than having it assembled here.
export async function fcmPost(
  ctx: any,
  message: Record<string, unknown>,
): Promise<void> {
  const saJson = process.env.FCM_SERVICE_ACCOUNT_JSON;
  if (!saJson) {
    throw new Error("FCM_MISCONFIG: missing FCM_SERVICE_ACCOUNT_JSON");
  }
  let sa: { client_email: string; private_key: string; project_id: string };
  try {
    sa = JSON.parse(saJson);
  } catch (e) {
    // Malformed service-account JSON is a deployment misconfiguration, not
    // a bad device token.
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`FCM_MISCONFIG: invalid FCM_SERVICE_ACCOUNT_JSON (${msg})`);
  }
  const accessToken = await fcmAccessToken(ctx, sa);
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ message }),
    },
  );
  if (!res.ok) throw fcmError(res.status, await res.text());
}

function fcmError(status: number, body: string): Error {
  // 404 is unambiguous, and UNREGISTERED/SENDER_ID_MISMATCH name the token
  // explicitly. Everything else that arrives as 400 is INVALID_ARGUMENT, which
  // covers both "your token is garbage" and "your payload is garbage" — and the
  // naive version of this check treated a malformed payload as a dead token and
  // wiped it. Only clear when the error points at the token field.
  if (status === 404) return new Error(`FCM_BAD_TOKEN:404:${body}`);
  if (body.includes("UNREGISTERED") || body.includes("SENDER_ID_MISMATCH")) {
    return new Error(`FCM_BAD_TOKEN:${status}:${body}`);
  }
  if (status === 400) {
    const namesToken =
      body.includes("message.token") ||
      body.includes("registration token") ||
      body.includes("registration-token");
    return namesToken
      ? new Error(`FCM_BAD_TOKEN:400:${body}`)
      : new Error(`FCM_MISCONFIG: 400 ${body}`);
  }
  if (status === 401 || status === 403) {
    return new Error(`FCM_MISCONFIG: HTTP ${status}: ${body}`);
  }
  if (status === 429 || status >= 500) {
    return new Error(`FCM_TRANSIENT: HTTP ${status}: ${body}`);
  }
  return new Error(`FCM HTTP ${status}: ${body}`);
}

async function fcmAccessToken(
  ctx: any,
  sa: { client_email: string; private_key: string },
): Promise<string> {
  // Google access tokens are valid for 60 min — cache and reuse like the
  // APNs JWT instead of a sign + OAuth round-trip per push.
  return cachedProviderToken(ctx, "fcm", sa.client_email, async () => {
    const iat = Math.floor(Date.now() / 1000);
    const jwt = await signJwt(
      { alg: "RS256", typ: "JWT" },
      {
        iss: sa.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat,
        exp: iat + 3600,
      },
      sa.private_key,
      "RS256",
    );
    const params = new URLSearchParams();
    params.set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer");
    params.set("assertion", jwt);
    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: params.toString(),
    });
    if (!res.ok) {
      throw new Error(`FCM OAuth HTTP ${res.status}: ${await res.text()}`);
    }
    const j = (await res.json()) as { access_token: string };
    return j.access_token;
  });
}

/** FCM v1 requires every `data` value to be a string. */
export function stringifyValues(
  o: Record<string, unknown>,
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const k of Object.keys(o)) {
    const val = o[k];
    if (val === undefined || val === null) continue;
    out[k] = typeof val === "string" ? val : String(val);
  }
  return out;
}
