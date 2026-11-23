import { mutation, publicMutation } from "./functions";
import { v } from "convex/values";
import { hashToken, mintSession } from "./sessionCore";
import { markOnline } from "./presenceCore";
import { getLiveUser } from "./deletionCore";
import { assertNotLocked, noteFailure, refusal } from "./rateLimit";
import { ACCOUNT_CHILD, ERR_NOT_ALLOWED } from "./childGuard";

/**
 * "Continue as @name" on a second device of the same Apple or Google account.
 *
 * A signed-in device asks for a key ([mint]) and saves it into the account's
 * own synced credential store: iCloud Keychain on Apple platforms, Google
 * Password Manager (Credential Manager) on Android. A fresh install on another
 * device of that account finds it there, asks the person whether to continue,
 * and trades it for a session of its own ([redeem]).
 *
 * This is the only path besides pairing into a child account, and it is the
 * point: a child who was paired once should not need a guardian's code again
 * for their own tablet. The trust is the platform account's. Whoever unlocks a
 * device signed into the child's Apple / Google account already is the child
 * as far as the OS is concerned, and the guardian still sees and can sign out
 * every device in the Devices list.
 *
 * CHILD ACCOUNTS ONLY, enforced here and not just in the app. Families share
 * one Apple ID or Google account across a parent's phone and a kid's iPad all
 * the time. A key for an ADULT account in that shared store would let the kid
 * tap "Continue as @parent" on a fresh install and skip the parent's password.
 * The other direction (a parent continuing as their own child) is harmless:
 * they can pair that account whenever they like. A graduated account has a
 * password of its own, so its keys stop working the moment it graduates.
 *
 * The key is 256 bits of CSPRNG output, minted here and returned once. Only its
 * sha256 is stored, the same treatment sessions get (`sessionCore.hashToken`).
 *
 * Cost (handbook R17): mint = 1 bounded index read (≤ CAP + 1 rows) + 1 insert
 * (+ ≤ 1 delete). Redeem = 1 indexed read + the user + the device row + the
 * normal session mint, 3 small writes. Both are one-off per device, no
 * subscription reads either table, no cron, zero idle cost.
 */

/** Keys kept per account; minting another evicts the oldest. */
export const CONTINUE_KEYS_PER_USER = 5;

/** A key nobody has used for this long is refused and deleted on contact. */
export const CONTINUE_KEY_IDLE_MS = 180 * 24 * 60 * 60 * 1000;

export const ERR_CONTINUE_KEY_INVALID = "CONTINUE_KEY_INVALID";

const continueDeviceKey = (deviceId: string) => `continue:device:${deviceId}`;
const MAX_CONTINUE_DEVICE_FAILURES = 10;

function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Mints a key for the signed-in account. The plaintext is returned once and
 * never stored.
 */
export const mint = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const me = await ctx.db.get(userId);
    if (me?.accountType !== ACCOUNT_CHILD) throw new Error(ERR_NOT_ALLOWED);
    const now = Date.now();
    const existing = await ctx.db
      .query("continueKeys")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .take(CONTINUE_KEYS_PER_USER + 1);
    // Oldest first by creation, so the device that minted most recently keeps
    // a working key.
    existing.sort((a, b) => a.createdAt - b.createdAt);
    const excess = existing.length - (CONTINUE_KEYS_PER_USER - 1);
    for (let i = 0; i < excess; i++) await ctx.db.delete(existing[i]._id);

    const key = randomHex(32);
    await ctx.db.insert("continueKeys", {
      userId,
      keyHash: await hashToken(key),
      createdAt: now,
    });
    return { key };
  },
});

/**
 * Trades a key from the synced store for a session on this device. Returns the
 * same shape as `auth.login` plus `accountType`, so the client adopts it the
 * way it adopts pairing.
 */
export const redeem = publicMutation({
  args: {
    key: v.string(),
    deviceId: v.string(),
    deviceSecret: v.optional(v.string()),
    platform: v.string(),
    deviceName: v.optional(v.string()),
  },
  handler: async (ctx, { key, deviceId, deviceSecret, platform, deviceName }) => {
    const bucket = continueDeviceKey(deviceId);
    await assertNotLocked(ctx, bucket);
    const now = Date.now();
    // Anything but the 64 hex chars [mint] hands out cannot match a row, so it
    // skips the read but still counts as a guess.
    let found = null;
    if (/^[0-9a-f]{64}$/.test(key)) {
      const keyHash = await hashToken(key);
      found = await ctx.db
        .query("continueKeys")
        .withIndex("by_keyHash", (q) => q.eq("keyHash", keyHash))
        .first();
    }
    if (!found) {
      await noteFailure(ctx, bucket, MAX_CONTINUE_DEVICE_FAILURES);
      return refusal(ERR_CONTINUE_KEY_INVALID);
    }
    const lastUsed = found.lastUsedAt ?? found.createdAt;
    if (now - lastUsed > CONTINUE_KEY_IDLE_MS) {
      await ctx.db.delete(found._id);
      return refusal(ERR_CONTINUE_KEY_INVALID);
    }
    const user = await getLiveUser(ctx, found.userId);
    if (!user || user.accountType !== ACCOUNT_CHILD) {
      await ctx.db.delete(found._id);
      return refusal(ERR_CONTINUE_KEY_INVALID);
    }

    await ctx.db.patch(found._id, { lastUsedAt: now });
    await markOnline(ctx, user._id, { now });

    // Same device registration pairing does, so calls and pushes reach it.
    const device = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", user._id).eq("deviceId", deviceId),
      )
      .first();
    if (device) {
      await ctx.db.patch(device._id, { platform, deviceName, lastSeenAt: now });
    } else {
      await ctx.db.insert("userDevices", {
        userId: user._id,
        deviceId,
        platform,
        deviceName,
        lastSeenAt: now,
        createdAt: now,
      });
    }

    return {
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
      accountType: ACCOUNT_CHILD,
      token: await mintSession(ctx, user._id, deviceId, deviceSecret),
    };
  },
});
