// Profile write logic (Phase 6): the `profiles` row is what readers resolve a
// person's name and face from, so no reader needs a `users` row (which the
// presence heartbeat and every other hot write used to churn) and no writer
// needs to copy a name onto a message, moment or reaction.
//
// Every code path that changes `users.name`, `username`, `avatarStorageId` or
// `visibility.avatar` calls `syncProfile` in the SAME transaction. Account
// deletion calls `tombstoneProfile`. Nothing here rate-limits or authenticates.
//
// `updatedAt` is the version the client caches by (`profiles:versions`), so it
// only ever moves forward: `max(prev + 1, now)` even if the clock steps back.
import { isSystemAccount } from "./systemAccount";

/**
 * True until the copies are stripped (stage W3). Writers of the denormalised
 * name/avatar copies (`messages.senderName`, `moments.authorName`, ...) check
 * this and keep writing while it is true, so old builds keep rendering.
 */
export const PROFILE_COPIES = true;

type ProfileFields = {
  name: string;
  username: string;
  avatarStorageId: any;
  avatarLevel: string | undefined;
  deleted: boolean | undefined;
  isSystem: boolean | undefined;
};

async function profileRow(ctx: any, userId: any) {
  return await ctx.db
    .query("profiles")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

/** The row `users` implies, or null when the user row is gone. */
function desiredFrom(user: any): ProfileFields {
  if (user.deletingAt !== undefined) return TOMBSTONE;
  return {
    name: user.name ?? user.username,
    username: user.username,
    avatarStorageId: user.avatarStorageId,
    avatarLevel: user.visibility?.avatar,
    deleted: undefined,
    isSystem: isSystemAccount(user) ? true : undefined,
  };
}

const TOMBSTONE: ProfileFields = {
  name: "",
  username: "",
  avatarStorageId: undefined,
  avatarLevel: undefined,
  deleted: true,
  isSystem: undefined,
};

const FIELDS: (keyof ProfileFields)[] = [
  "name",
  "username",
  "avatarStorageId",
  "avatarLevel",
  "deleted",
  "isSystem",
];

async function write(
  ctx: any,
  userId: any,
  existing: any,
  want: ProfileFields,
): Promise<{ changed: boolean }> {
  const now = Date.now();
  if (!existing) {
    await ctx.db.insert("profiles", { userId, ...want, updatedAt: now });
    return { changed: true };
  }
  const patch: Record<string, unknown> = {};
  for (const f of FIELDS) {
    if (existing[f] !== want[f]) patch[f] = want[f];
  }
  if (Object.keys(patch).length === 0) return { changed: false };
  patch.updatedAt = Math.max((existing.updatedAt ?? 0) + 1, now);
  await ctx.db.patch(existing._id, patch);
  return { changed: true };
}

/**
 * Make the user's profile row match their `users` row. Inserts if missing,
 * patches only on a difference (a no-op writes nothing, so it wakes no
 * subscriber), and tombstones a user already marked `deletingAt`. Call it in
 * the same transaction as the `users` write. A missing user row is a no-op.
 */
export async function syncProfile(
  ctx: any,
  userId: any,
): Promise<{ changed: boolean }> {
  const user = await ctx.db.get(userId);
  if (!user) return { changed: false };
  return await write(ctx, userId, await profileRow(ctx, userId), desiredFrom(user));
}

/**
 * The account is gone: keep the row as `{deleted: true}` with no name,
 * username or avatar, so old rows resolve to "deleted user" and the avatar
 * file hold is dropped. Idempotent; inserts the tombstone if no row existed.
 */
export async function tombstoneProfile(
  ctx: any,
  userId: any,
): Promise<{ changed: boolean }> {
  return await write(ctx, userId, await profileRow(ctx, userId), TOMBSTONE);
}

/**
 * A person's display name by point read. A deleted user gives "" (callers map
 * that to their own "deleted user" label). Until `backfillProfiles` has run, a
 * missing row falls back to the `users` row, and a missing user gives "".
 */
export async function nameOf(ctx: any, userId: any): Promise<string> {
  const row = await profileRow(ctx, userId);
  if (row) return row.deleted ? "" : row.name;
  const user = await ctx.db.get(userId);
  if (!user || user.deletingAt !== undefined) return "";
  return user.name ?? user.username;
}
