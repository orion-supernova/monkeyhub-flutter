import { seenVisibilityOf } from "./visibility";
import { LOG_ROOM_POSTING_PRESET } from "./roomPolicy";
import {
  SYSTEM_PASSWORD_PREFIX,
  SYSTEM_VISIBILITY,
  isSystemAccount,
} from "./systemAccount";

/**
 * A system account and the one private staff room it posts into, created on
 * first use and repaired in place on every use after that.
 *
 * Lifted out of `problemReports.ts`, where it was written for the log account
 * alone, when the moderation inbox (`Monkey Reporter`, `moderationCore.ts`)
 * needed exactly the same thing. A second copy would have been a second place
 * for the invariants below to drift — the membership-keyed lookup, the
 * patch-only-when-different repair, the additive roster — and every one of
 * them was learned the hard way the first time. So both inboxes are now one
 * [SystemRoomSpec] each, and this module is the only code that writes a
 * system account's row or its room.
 *
 * Imports no mutation module (only `visibility`, `roomPolicy` and
 * `systemAccount`, none of which import back), so `messages.ts` can reach the
 * moderation inbox through `moderationCore.ts` without a cycle.
 */

/** Everything that distinguishes one system inbox from another. */
export type SystemRoomSpec = {
  /** The account's handle. Must be inside a reserved substring. */
  username: string;
  /** The account's display name, which signs every post. */
  displayName: string;
  /** The room's display name. Never used as a lookup key. */
  roomName: string;
  /** `rooms.system` — the slug the client keys capabilities off. */
  slug: string;
  /**
   * A pre-slug shape this function should adopt rather than duplicate, for a
   * deployment whose room predates `rooms.system`. Only the log room has one.
   */
  isLegacyRoom?: (room: any, accountId: any) => boolean;
};

/** Same shape as `messages.mintNonce` — see the note there on `Math.random`. */
function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * The system account, created on first use.
 *
 * Created lazily rather than seeded by a migration so a fresh deployment needs
 * no setup step.
 *
 * Throws if the handle is already held by a REAL account. `isReservedName`
 * refuses the handle at every signup path, so this cannot happen going
 * forward — but a deployment that predates a reservation could already have
 * one, and quietly posting as somebody else's account would put messages the
 * user never wrote into their sent history. A collision has to stop the post,
 * not reroute it.
 */
export async function ensureSystemAccount(
  ctx: any,
  spec: SystemRoomSpec,
): Promise<any> {
  const existing = await ctx.db
    .query("users")
    .withIndex("by_username", (q: any) => q.eq("username", spec.username))
    .first();
  if (existing) {
    if (!isSystemAccount(existing)) {
      throw new Error(`${spec.username.toUpperCase()}_USERNAME_TAKEN`);
    }
    // Repair a row created before `SYSTEM_VISIBILITY` existed, which would
    // otherwise keep the server's "public" defaults for avatar and presence.
    // Idempotent: patched only when it differs, so this is not a write per
    // post.
    if (existing.visibility?.avatar !== SYSTEM_VISIBILITY.avatar) {
      await ctx.db.patch(existing._id, { visibility: SYSTEM_VISIBILITY });
    }
    return existing._id;
  }

  return await ctx.db.insert("users", {
    username: spec.username,
    name: spec.displayName,
    passwordHash: SYSTEM_PASSWORD_PREFIX + randomHex(16),
    createdAt: Date.now(),
    // Never "online": this account has no client and no heartbeat, and it
    // keeps the row permanently outside `sweepStalePresence`, which ranges
    // only within status "online" and "away".
    status: "offline",
    // No `lastSeen`: there is no last time this account was seen.
    //
    // The visibility block is what makes the account private. Leaving it
    // absent would hand this account `visibility.DEFAULT_LEVEL`: a public face,
    // and presence and read receipts shared with friends.
    visibility: SYSTEM_VISIBILITY,
    // `avatarStorageId` is deliberately absent. A mutation cannot create a
    // blob, so the avatar is deployment data, set with `systemAvatars:set`.
    // Until then the client draws its usual monogram.
  });
}

/**
 * Finds the account's room by the only key that has ever been reliable: the
 * account's own membership.
 *
 * NOT by name. Room names are not reserved, so any user may create a group
 * called "MonkeyHub Moderation" and a `by_name` lookup would hand back theirs;
 * and a lookup that misses does not fail loudly, it creates a SECOND inbox and
 * silently orphans everything already filed in the first.
 *
 * The account has no client and no session, so it joins nothing on its own and
 * this module is the only thing that writes a `roomMembers` row for it. The
 * membership is still a filter and not the whole answer, because `rooms.join`
 * takes the joining user as an argument — so a candidate must also carry the
 * slug (or the spec's legacy shape). Anything else the account somehow ended
 * up in is skipped rather than adopted and renamed.
 */
async function findSystemRoom(ctx: any, spec: SystemRoomSpec, accountId: any) {
  const memberships = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", (q: any) => q.eq("userId", accountId))
    .collect();
  let legacy: any = null;
  for (const m of memberships) {
    const room = await ctx.db.get(m.roomId);
    if (!room) continue;
    if (room.system === spec.slug) return room;
    if (spec.isLegacyRoom?.(room, accountId)) legacy = room;
  }
  return legacy;
}

/**
 * The room for [spec], created on first use: a private group owned by the
 * account, with every staff reader in it. Returns the room id.
 *
 * In place, with no backfill job: an existing room holds everything ever
 * filed, so it is patched where it differs and left alone where it does not,
 * which also makes this the repair path for a room whose roster has drifted or
 * whose count is stale.
 */
export async function ensureSystemRoom(
  ctx: any,
  spec: SystemRoomSpec,
  accountId: any,
  readerIds: any[],
): Promise<any> {
  const existing = await findSystemRoom(ctx, spec, accountId);
  const roomId = existing
    ? await repairSystemRoom(ctx, spec, existing, accountId)
    : await ctx.db.insert("rooms", {
        name: spec.roomName,
        createdBy: accountId,
        createdAt: Date.now(),
        // Never discoverable: `by_visibility` lists public rooms only.
        isPrivate: true,
        // Corrected by `reconcileSystemRoomMembers` below, in this same
        // mutation, so no reader ever observes the zero.
        memberCount: 0,
        type: "Regular Room",
        // What tells the client this is a fixture and not a conversation.
        system: spec.slug,
        // Members read; only the account posts. A system room resolves to
        // read-only without this too (`roomPolicy.postingPresetOf`), but the
        // stamp says so on the row rather than by inference.
        postingPolicy: LOG_ROOM_POSTING_PRESET,
        avatarStorageId: (await ctx.db.get(accountId))?.avatarStorageId,
        // No `messageLifetime`. A Chamber-of-Secrets lifetime here would
        // delete reports on a timer; each inbox runs its own retention sweep.
      });
  await reconcileSystemRoomMembers(ctx, roomId, accountId, readerIds);
  return roomId;
}

/**
 * Brings an existing room up to the current shape. Every field is patched
 * only when it actually differs: this runs on every post, `rooms` is a live
 * subscription, and an unconditional patch would re-fire the room list of
 * everyone in it once per report for no change at all.
 */
async function repairSystemRoom(
  ctx: any,
  spec: SystemRoomSpec,
  room: any,
  accountId: any,
): Promise<any> {
  const patch: Record<string, any> = {};
  if (room.system !== spec.slug) patch.system = spec.slug;
  // Stamped only when ABSENT, so a deliberate later change of the preset is
  // not undone by the next post.
  if (room.postingPolicy === undefined) {
    patch.postingPolicy = LOG_ROOM_POSTING_PRESET;
  }
  if (room.name !== spec.roomName) patch.name = spec.roomName;
  // A public inbox would be listed in Discover, which is the one place these
  // posts must never appear.
  if (room.isPrivate !== true) patch.isPrivate = true;
  if (!room.avatarStorageId) {
    const avatar = (await ctx.db.get(accountId))?.avatarStorageId;
    if (avatar) patch.avatarStorageId = avatar;
  }
  if (Object.keys(patch).length > 0) await ctx.db.patch(room._id, patch);
  return room._id;
}

/**
 * Puts the account and every staff reader in the room, and makes `memberCount`
 * agree with the rows.
 *
 * Additive only: it inserts what is missing and never removes anybody.
 * Revoking access is a deliberate act at a moment somebody chose, not a side
 * effect of a stranger tapping "send" on a report.
 */
async function reconcileSystemRoomMembers(
  ctx: any,
  roomId: any,
  accountId: any,
  readerIds: any[],
): Promise<void> {
  const rows = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  const byUser = new Map<string, any>(
    rows.map((r: any) => [r.userId.toString(), r]),
  );
  const present = new Set<string>(byUser.keys());

  // The account owns the room, and it is the only owner that keeps working:
  // every human in here is a reader who may come and go.
  const botRow = byUser.get(accountId.toString());
  if (!botRow) {
    await ctx.db.insert("roomMembers", {
      roomId,
      userId: accountId,
      joinedAt: Date.now(),
      role: "owner",
      seenVisibility: await seenVisibilityOf(ctx, accountId),
    });
    present.add(accountId.toString());
  } else if (botRow.role !== "owner") {
    await ctx.db.patch(botRow._id, { role: "owner" });
  }

  for (const readerId of readerIds) {
    const key = readerId.toString();
    if (present.has(key)) continue;
    await ctx.db.insert("roomMembers", {
      roomId,
      userId: readerId,
      joinedAt: Date.now(),
      role: "member",
      // No `lastReadAt`: the backlog counts as unread to somebody newly
      // responsible for reading it, which is the honest number.
      seenVisibility: await seenVisibilityOf(ctx, readerId),
    });
    present.add(key);
  }

  const room = await ctx.db.get(roomId);
  if (room && room.memberCount !== present.size) {
    await ctx.db.patch(roomId, { memberCount: present.size });
  }
}

/**
 * Resolves [usernames] to human accounts, in order, skipping any that name
 * nobody, name a system account, or repeat. Callers that need one of them to
 * exist (the log room's inbox) check that themselves.
 */
export async function resolveStaff(
  ctx: any,
  usernames: readonly string[],
): Promise<any[]> {
  const out: any[] = [];
  const seen = new Set<string>();
  for (const username of usernames) {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q: any) => q.eq("username", username))
      .first();
    if (!user) continue;
    if (isSystemAccount(user)) continue;
    if (seen.has(user._id.toString())) continue;
    seen.add(user._id.toString());
    out.push(user);
  }
  return out;
}

/**
 * Makes the account and one reader accepted contacts, both directions.
 *
 * What it buys is the face: `SYSTEM_VISIBILITY` sets the account's avatar to
 * `"friends"`, so its picture reaches accepted contacts and nobody else — the
 * set of people who can see the account is exactly the set in its room.
 * Written in both directions because the friends list is read from `by_user`
 * only. Never downgrades or re-stamps a row that is already right.
 */
export async function ensureSystemFriendship(
  ctx: any,
  a: any,
  b: any,
  roomId: any,
): Promise<void> {
  for (const [userId, friendId] of [
    [a, b],
    [b, a],
  ]) {
    const existing = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", userId).eq("friendId", friendId),
      )
      .first();
    if (existing) {
      if (existing.status !== "accepted") {
        await ctx.db.patch(existing._id, {
          status: "accepted",
          respondedAt: Date.now(),
          stage: undefined,
          deniedBy: undefined,
        });
      }
      continue;
    }
    await ctx.db.insert("friendships", {
      userId,
      friendId,
      status: "accepted",
      createdAt: Date.now(),
      respondedAt: Date.now(),
      roomId,
    });
  }
}

/**
 * The whole provisioning step for one inbox: account, room, roster, contacts.
 * Returns the ids a poster needs.
 */
export async function provisionSystemInbox(
  ctx: any,
  spec: SystemRoomSpec,
  readers: any[],
): Promise<{ accountId: any; roomId: any }> {
  const accountId = await ensureSystemAccount(ctx, spec);
  const roomId = await ensureSystemRoom(
    ctx,
    spec,
    accountId,
    readers.map((u) => u._id),
  );
  for (const reader of readers) {
    await ensureSystemFriendship(ctx, accountId, reader._id, roomId);
  }
  return { accountId, roomId };
}
