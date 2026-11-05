// Which of a person's devices they are chatting on right now.
//
// The problem it answers: someone signed in on a phone, a Mac, a Linux box and
// a browser tab, replying from the phone, had every other screen chime and
// banner for each line of the conversation they were already reading. Every
// device was right on its own terms (its own app was not in front) and the
// sum was absurd.
//
// The fix is the rule Telegram and iMessage follow: while you are active on
// one device, the others stay quiet. Quiet, not silent-by-omission: the push
// still goes, so the notification is in Notification Center / the shade when
// you pick that device up, and reading the room anywhere sweeps it as before.
// Only the sound, the banner and the lit screen are taken away.
//
// "Active" is evidence, not a claim: this device sent a message, read a room,
// or came to the front, within [ENGAGED_MS]. A window left open on a desk
// stops counting two minutes after the last thing done in it, so walking away
// from the Mac cannot mute the phone for the evening. And it is cleared the
// moment that device reports going to the background.
//
// ONE row per person, holding the most recently engaged device. "Which device
// am I using" has a single answer, and the newest evidence wins: picking up
// the phone mid-conversation moves the row to the phone on its first read.
//
// Cost: a write at most every [STAMP_EVERY_MS] per person while they chat (or
// immediately on a device switch), into a table nothing subscribes to; and
// one indexed read per recipient per message push, in `_loadAlertTargets`.
import { v } from "convex/values";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { query } from "./functions";
import { callerSessionId } from "./sessionCore";

/** How long one act of chatting keeps a device the engaged one. */
export const ENGAGED_MS = 120_000;

/** A repeat stamp from the same device younger than this is not rewritten. */
export const STAMP_EVERY_MS = 30_000;

/** The device the calling session belongs to, or null outside the wrappers. */
async function callerDeviceId(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
): Promise<string | null> {
  const sessionId = callerSessionId(ctx);
  if (sessionId === undefined) return null;
  const s = await ctx.db.get(sessionId);
  if (s === null || s.userId !== userId || s.revokedAt !== undefined) {
    return null;
  }
  return s.deviceId;
}

async function rowFor(ctx: QueryCtx | MutationCtx, userId: Id<"users">) {
  return await ctx.db
    .query("deviceEngagement")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .first();
}

/**
 * The calling device is in use. Called from the acts that prove it: sending,
 * reading a room, coming to the front. Cheap when repeated: a same-device
 * stamp inside [STAMP_EVERY_MS] is one indexed read and no write.
 */
export async function noteEngaged(
  ctx: MutationCtx,
  userId: Id<"users">,
  now: number = Date.now(),
): Promise<void> {
  const deviceId = await callerDeviceId(ctx, userId);
  if (deviceId === null) return;
  const row = await rowFor(ctx, userId);
  if (row === null) {
    await ctx.db.insert("deviceEngagement", { userId, deviceId, at: now });
    return;
  }
  if (row.deviceId === deviceId && now - row.at < STAMP_EVERY_MS) return;
  await ctx.db.patch(row._id, { deviceId, at: now });
}

/**
 * The calling device went to the background. Clears the row only when it is
 * THIS device's: a phone being locked must not un-quiet the Mac's peers when
 * the Mac is the one in use.
 */
export async function noteDisengaged(
  ctx: MutationCtx,
  userId: Id<"users">,
): Promise<void> {
  const deviceId = await callerDeviceId(ctx, userId);
  if (deviceId === null) return;
  const row = await rowFor(ctx, userId);
  if (row !== null && row.deviceId === deviceId) await ctx.db.delete(row._id);
}

/** The device [userId] is chatting on at [now], or null if none. */
export async function engagedDeviceId(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
  now: number,
): Promise<string | null> {
  const row = await rowFor(ctx, userId);
  if (row === null || now - row.at >= ENGAGED_MS) return null;
  return row.deviceId;
}

/**
 * Whether the caller is chatting on a DIFFERENT device right now. Asked by the
 * clients that alert from the socket rather than from a push (Linux banners,
 * Windows and web pings), just before they would make a noise.
 *
 * A one-shot query, never a subscription: the answer is wanted once per alert
 * burst, and a subscription would refire on every stamp. `Date.now()` is
 * deliberate for the same reason, since nothing caches this.
 */
export const engagedElsewhere = query({
  args: {},
  returns: v.boolean(),
  handler: async (ctx, { userId }) => {
    const mine = await callerDeviceId(ctx, userId);
    const engaged = await engagedDeviceId(ctx, userId, Date.now());
    return engaged !== null && engaged !== mine;
  },
});
