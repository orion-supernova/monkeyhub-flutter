import { internalMutation } from "./_generated/server";
import { mutation, publicMutation, publicQuery, query } from "./functions";
import { mintSession } from "./sessionCore";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import type { MutationCtx } from "./_generated/server";
import { assertNotLocked, clearFailures, noteFailure } from "./rateLimit";

/**
 * QR / short-code sign-in for a signed-out web or desktop client — the
 * "scan this with your phone" pattern (WhatsApp Web, Telegram Desktop,
 * Discord). Mirrors `family.ts`'s pairing-code shape deliberately: a mint
 * step, a single-use redeem step, hashed short codes, and a short TTL. See
 * the `deviceLoginRequests` comment in schema.ts for why this is its own
 * table and what each field is for.
 *
 * State machine: "pending" → "approved" | "denied" by the phone,
 * "approved" → "consumed" the instant the desktop collects its session. No
 * stored "expired" — every read/write that matters checks `expiresAt`
 * inline instead, exactly like `family.redeemPairingCode` does.
 */

/** A "someone is standing at their computer right now" flow — much shorter
 * than `family.PAIRING_TTL_MS`, which can be read aloud over a phone call. */
const REQUEST_TTL_MS = 3 * 60 * 1000;

/** Cap on the client-supplied device-info string. Shown verbatim to the
 * phone at approval time; this is hygiene against an accidental essay, not a
 * defense against anything — the string is never trusted for more than
 * display. */
const MAX_DEVICE_INFO_CHARS = 200;

export const ERR_REQUEST_INVALID = "DEVICE_LOGIN_REQUEST_INVALID";
export const ERR_REQUEST_EXPIRED = "DEVICE_LOGIN_REQUEST_EXPIRED";
export const ERR_REQUEST_DENIED = "DEVICE_LOGIN_DENIED";
export const ERR_REQUEST_NOT_APPROVED = "DEVICE_LOGIN_NOT_APPROVED";
export const ERR_CODE_INVALID = "DEVICE_LOGIN_CODE_INVALID";
export const ERR_CODE_EXPIRED = "DEVICE_LOGIN_CODE_EXPIRED";

/** Same shape as `messages.mintNonce` / `problemReports.randomHex` — see the
 * note on those about why `crypto.getRandomValues` and not `Math.random`. 16
 * bytes (32 hex chars) is far more entropy than the six digits a human ever
 * has to type, which is the whole reason the QR carries this instead. */
function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

const deviceLoginKey = (userId: Id<"users">) => `deviceLogin:${userId}`;

/**
 * Starts a request. Called by the desktop/web client on the login screen
 * mounting — before anyone is signed in, so this takes no identity at all.
 *
 * [codeHash] is the six-digit fallback, generated and hashed on the CALLER's
 * side the same way `family.createPairingCode` handles a pairing code —
 * plaintext never reaches this table. `requestId` is minted here instead,
 * because the QR needs far more entropy than a human ever has to type; see
 * the schema comment for why the two are not the same secret.
 */
export const createLoginRequest = publicMutation({
  args: {
    deviceInfo: v.string(),
    codeHash: v.string(),
  },
  handler: async (ctx, { deviceInfo, codeHash }) => {
    const now = Date.now();
    const requestId = randomHex(16);
    const expiresAt = now + REQUEST_TTL_MS;
    await ctx.db.insert("deviceLoginRequests", {
      requestId,
      codeHash,
      status: "pending",
      deviceInfo: deviceInfo.slice(0, MAX_DEVICE_INFO_CHARS),
      createdAt: now,
      expiresAt,
    });
    return { requestId, expiresAt };
  },
});

/**
 * Live status of one request, keyed by `requestId`. The desktop/web client
 * subscribes to this — Convex queries are reactive by construction, so the
 * moment the phone decides, this update lands with no polling.
 *
 * Deliberately the ONLY thing this returns. No `deviceInfo`, no
 * `approvedByUserId`, and above all no session — a subscribed query's last
 * value sits in whatever is watching it (including an open devtools tab),
 * which is exactly the channel `exchangeDeviceLoginRequest` exists to avoid
 * using for the actual credential.
 */
export const getDeviceLoginRequestStatus = publicQuery({
  args: { requestId: v.string() },
  handler: async (ctx, { requestId }) => {
    const row = await ctx.db
      .query("deviceLoginRequests")
      .withIndex("by_requestId", (q) => q.eq("requestId", requestId))
      .first();
    if (!row) return { status: "invalid" as const };
    if (row.status === "pending" && row.expiresAt < Date.now()) {
      return { status: "expired" as const };
    }
    return { status: row.status as "pending" | "approved" | "denied" | "consumed" };
  },
});

/**
 * Finds the pending row a phone is about to act on, from either the QR
 * (`requestId`) or the typed fallback (`codeHash`) — exactly one must be
 * set. Shared by `peekDeviceLoginRequest` and `respondToDeviceLoginRequest`
 * so the validation — and the rate limit — can't drift between "show the
 * confirmation" and "act on it": a hand-rolled client that skips the peek
 * and calls respond directly must hit the same throttle a normal one would.
 *
 * Only the `codeHash` path is throttled. `requestId` came out of a QR code;
 * guessing 32 hex characters is not a real attack surface. Guessing six
 * digits is, and unlike a pairing code — where the worst case is pairing
 * somebody else's *child* device to yourself — a wrong guess here is an
 * attempt to sign a stranger's browser into your own account, so it runs
 * behind the same failed-attempt throttle `auth.login` uses.
 */
async function resolveRequest(
  ctx: MutationCtx,
  args: {
    requestId?: string;
    codeHash?: string;
    callerId: Id<"users">;
  },
): Promise<Doc<"deviceLoginRequests">> {
  const { requestId, codeHash, callerId } = args;
  if ((requestId == null) === (codeHash == null)) {
    // Both set or neither — a client bug, never a real user path.
    throw new Error(ERR_REQUEST_INVALID);
  }

  let row: Doc<"deviceLoginRequests"> | null;
  if (requestId != null) {
    row = await ctx.db
      .query("deviceLoginRequests")
      .withIndex("by_requestId", (q) => q.eq("requestId", requestId))
      .first();
    if (!row) throw new Error(ERR_REQUEST_INVALID);
  } else {
    const key = deviceLoginKey(callerId);
    await assertNotLocked(ctx, key);
    row = await ctx.db
      .query("deviceLoginRequests")
      .withIndex("by_codeHash", (q) => q.eq("codeHash", codeHash!))
      .first();
    if (!row) {
      await noteFailure(ctx, key);
      throw new Error(ERR_CODE_INVALID);
    }
    await clearFailures(ctx, key);
  }

  if (row.status === "pending" && row.expiresAt < Date.now()) {
    throw new Error(requestId != null ? ERR_REQUEST_EXPIRED : ERR_CODE_EXPIRED);
  }
  // Already decided (or already exchanged) — nothing left for a peek or a
  // fresh response to do with it.
  if (row.status !== "pending") {
    throw new Error(ERR_REQUEST_INVALID);
  }
  return row;
}

/**
 * Phone-side peek, before showing the "approve this device?" confirmation.
 * Read-only in spirit but a mutation in practice — the throttle in
 * [resolveRequest] has to record failures somewhere, and Convex queries
 * cannot write.
 */
export const peekDeviceLoginRequest = mutation({
  args: {
    callerId: v.id("users"),
    requestId: v.optional(v.string()),
    codeHash: v.optional(v.string()),
  },
  handler: async (ctx, { callerId, requestId, codeHash }) => {
    const row = await resolveRequest(ctx, { requestId, codeHash, callerId });
    return { deviceInfo: row.deviceInfo };
  },
});

/**
 * Approves or denies a request, from the PHONE, authenticated as the
 * already-signed-in [callerId]. This is the only place `approvedByUserId`
 * is ever set — the desktop never chooses who it signs in as.
 */
export const respondToDeviceLoginRequest = mutation({
  args: {
    callerId: v.id("users"),
    approve: v.boolean(),
    requestId: v.optional(v.string()),
    codeHash: v.optional(v.string()),
  },
  handler: async (ctx, { callerId, approve, requestId, codeHash }) => {
    const row = await resolveRequest(ctx, { requestId, codeHash, callerId });
    await ctx.db.patch(
      row._id,
      approve
        ? { status: "approved", approvedByUserId: callerId, approvedAt: Date.now() }
        : { status: "denied" },
    );
  },
});

/**
 * Trades an APPROVED request for the session it names. Called by the
 * desktop/web client the instant its `getDeviceLoginRequestStatus`
 * subscription reports "approved" — see that query's doc comment for why the
 * session is handed out here and nowhere else. Single-use: the row is
 * stamped "consumed" in the same breath the session is read, so a second
 * exchange — or a replay of a captured `requestId` after the fact — gets
 * nothing.
 *
 * Returns the same `{ userId, username, name }` shape `auth.login` and
 * `family.redeemPairingCode` do, so the client's session-adoption code has
 * no idea which path it came from.
 */
export const exchangeDeviceLoginRequest = publicMutation({
  args: {
    requestId: v.string(),
    // The DESKTOP's device id — the one claiming the session, not the phone
    // that approved it. Binding it here is what puts the new sign-in in the
    // Devices list under its own name.
    deviceId: v.string(),
  },
  handler: async (ctx, { requestId, deviceId }) => {
    const row = await ctx.db
      .query("deviceLoginRequests")
      .withIndex("by_requestId", (q) => q.eq("requestId", requestId))
      .first();
    if (!row) throw new Error(ERR_REQUEST_INVALID);
    if (row.status === "denied") throw new Error(ERR_REQUEST_DENIED);
    if (row.status === "consumed") throw new Error(ERR_REQUEST_INVALID);
    if (row.status === "pending") {
      // Never approved, or it expired sitting there — either way the
      // desktop should not have called this yet; its own subscription is
      // what is supposed to gate the call.
      throw new Error(
        row.expiresAt < Date.now() ? ERR_REQUEST_EXPIRED : ERR_REQUEST_NOT_APPROVED,
      );
    }

    const user = await ctx.db.get(row.approvedByUserId!);
    if (!user) throw new Error(ERR_REQUEST_INVALID); // account deleted mid-flow

    await ctx.db.patch(row._id, { status: "consumed" });

    return {
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
      token: await mintSession(ctx, user._id, deviceId),
    };
  },
});

/**
 * Reaps every row past `expiresAt`, regardless of how it ended.
 *
 * Unlike `pairingCodes`/`releaseCodes` — where every row belongs to a child
 * and dies with the account, or is superseded the next time that guardian
 * mints a fresh one — a request here often belongs to nobody at all: the
 * desktop that created it may never be scanned, approved, or exchanged.
 * Nothing else in this app ever reaps that row, so unlike the two tables
 * above this one gets a real cron (see crons.ts). `expiresAt` is fixed at
 * creation no matter how the row ends, so anything past it is done one way
 * or another and safe to delete outright.
 */
export const gcExpiredDeviceLoginRequests = internalMutation({
  args: {},
  handler: async (ctx) => {
    const stale = await ctx.db
      .query("deviceLoginRequests")
      .withIndex("by_expiresAt", (q) => q.lt("expiresAt", Date.now()))
      .take(200);
    for (const r of stale) await ctx.db.delete(r._id);
  },
});
