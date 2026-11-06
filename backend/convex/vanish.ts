import { v } from "convex/values";
import { internalMutation } from "./dbHooks";
import { internal } from "./_generated/api";
import { mutation, query } from "./functions";
import { isTombstoned } from "./deletionCore";
import { removeMessageAndFanout } from "./messages";
import { assertNotSystemRoom } from "./systemAccount";
import { assertAdmin, isGroupRoom, membershipOf } from "./roomAdmin";
import { consume } from "./rateLimit";
import {
  AFTER_SEEN_OPTIONS,
  DEFAULT_AFTER_SEEN_SECONDS,
  VANISH_TTL_MS,
  cancelJob,
  ensureVanishState,
  isSecretRoom,
  recomputeFloor,
  vanishStateOf,
} from "./vanishCore";

/**
 * Vanish mode, the public surface and the two jobs. The state machine and the
 * rules are in vanishCore.ts; the design is docs/design/swipe-up-fork.html
 * (vanish, hidden seen, cleanup, budget).
 *
 * Every deletion goes through `removeMessageAndFanout`, the one message-delete
 * core (blobs, reactions, mention inbox, pins, push revoke, ...), with
 * `keepPreview` so a burn never patches the `rooms` row. Every job re-reads its
 * state, deletes by range and tolerates "already gone", so a retried or
 * duplicated job is harmless.
 */

/** Messages deleted per job run before it reschedules itself. */
const BURN_BATCH = 50;
const DEADLINE_BATCH = 50;
/** Rows looked at (not deleted) per run of the own-messages range. */
const SIDE_SCAN = 200;
/** Rooms with an overdue deadline job handled per backstop run. */
export const BACKSTOP_PAGE = 20;

// ───────────────────────────── system lines ──────────────────────────────

/**
 * One `system` message in [room], written by [actorId]. Machine-readable
 * content (`vanish:on:10`, `vanish:off`, `vanish:change:60`) that the client
 * renders in the reader's language. Carries no `vanishUntil`: the announcement
 * of a mode change is not itself vanishing. Patches the room preview in the
 * same write the caller already makes to the room.
 */
async function postSystemLine(
  ctx: any,
  room: any,
  actorId: any,
  content: string,
  preview: string,
): Promise<void> {
  const now = Date.now();
  await ctx.db.insert("messages", {
    roomId: room._id,
    userId: actorId,
    content,
    createdAt: now,
    type: "system",
  });
  await ctx.db.patch(room._id, {
    lastMessage: preview,
    lastMessageTime: now,
    lastMessageSenderId: actorId,
  });
}

// ───────────────────────────── mutations ─────────────────────────────────

/**
 * Turn vanish mode on or off in a REGULAR room.
 *
 * DM: either member. Group: whoever may edit room settings (admins), the same
 * rule as `rooms.updateRoom`. Secret rooms are refused (already self-
 * destructing). Idempotent: turning on when already on with the same timer is
 * a no-op, with no second system line. Only messages sent after the change are
 * affected. Passing a different `afterSeen` while on changes the timer (and
 * says so in a system line).
 */
export const setVanishMode = mutation({
  args: {
    roomId: v.id("rooms"),
    on: v.boolean(),
    afterSeen: v.optional(v.number()),
  },
  returns: v.object({ changed: v.boolean() }),
  handler: async (ctx, { roomId, userId, on, afterSeen }) => {
    const room = await ctx.db.get(roomId);
    if (!room || isTombstoned(room)) throw new Error("ROOM_NOT_FOUND");
    await assertNotSystemRoom(ctx, roomId);
    if (isSecretRoom(room) || room.messageLifetime) {
      throw new Error("VANISH_NOT_ALLOWED_IN_SECRET_ROOM");
    }
    if (afterSeen !== undefined && !AFTER_SEEN_OPTIONS.includes(afterSeen)) {
      throw new Error("BAD_VANISH_TIMER");
    }
    if (isGroupRoom(room)) {
      await assertAdmin(ctx, roomId, userId);
    } else if (!(await membershipOf(ctx, roomId, userId))) {
      throw new Error("NOT_AUTHORIZED");
    }

    const wasOn = room.vanishMode === true;
    const currentTimer = room.vanishAfterSeen ?? DEFAULT_AFTER_SEEN_SECONDS;
    const nextTimer = afterSeen ?? currentTimer;
    if (on === wasOn && (!on || nextTimer === currentTimer)) {
      return { changed: false };
    }
    await consume(ctx, `vanishtoggle:${userId}`, 30, 60 * 60 * 1000);

    const now = Date.now();
    if (on) {
      const next = { ...room, vanishMode: true, vanishAfterSeen: nextTimer };
      await ctx.db.patch(roomId, {
        vanishMode: true,
        vanishAfterSeen: nextTimer,
      });
      await ensureVanishState(ctx, next, now);
      await postSystemLine(
        ctx,
        room,
        userId,
        wasOn ? `vanish:change:${nextTimer}` : `vanish:on:${nextTimer}`,
        wasOn ? "Vanish timer changed" : "Vanish mode on",
      );
    } else {
      await ctx.db.patch(roomId, { vanishMode: false });
      const state = await vanishStateOf(ctx, roomId);
      // The row (and its deadline chain) outlives the mode until the last
      // message it promised is gone.
      if (state) await ctx.db.patch(state._id, { active: false });
      await postSystemLine(ctx, room, userId, "vanish:off", "Vanish mode off");
    }
    return { changed: true };
  },
});

/**
 * Whether this member's reads in [room] may count, decided server-side from
 * the user's own settings (used for the catch-up paths below; the hot path,
 * markRoomRead, takes the client's word, which can only expose its own reads).
 */
async function mayShareReads(ctx: any, userId: any, membership: any): Promise<boolean> {
  if (membership.vanishShareReads === true) return true;
  const user = await ctx.db.get(userId);
  const vis = user?.visibility;
  // `seen` defaults to "friends" (visibility.ts), i.e. not hidden.
  return (vis?.seen ?? "friends") !== "nobody" || vis?.vanishShareReads === true;
}

/**
 * The person agreed to share: their vanish cursor jumps to what they have
 * actually read, and the floor is recomputed once. Skipped when there is
 * nothing to catch up. Reads the vanishState only when the cursor moved.
 */
async function catchUp(ctx: any, membership: any, roomId: any): Promise<boolean> {
  const read = membership.lastReadAt ?? 0;
  const current = membership.vanishSeenAt ?? 0;
  if (read <= current) return false;
  await ctx.db.patch(membership._id, { vanishSeenAt: read });
  const state = await vanishStateOf(ctx, roomId);
  if (state) await recomputeFloor(ctx, state, Date.now());
  return true;
}

/**
 * The per-chat choice for people who hide "seen": share my reads in THIS
 * vanishing chat, or don't. Writes only the caller's own roomMembers row.
 * Sharing also counts what they have already read: their vanish cursor jumps
 * to their read cursor and anything below it burns after the grace period.
 * Not sharing never rewinds a cursor already given.
 */
export const setVanishShareReads = mutation({
  args: {
    roomId: v.id("rooms"),
    share: v.boolean(),
  },
  returns: v.null(),
  handler: async (ctx, { roomId, userId, share }) => {
    const membership = await membershipOf(ctx, roomId, userId);
    if (!membership) throw new Error("NOT_A_MEMBER");
    if (membership.vanishShareReads !== share) {
      await ctx.db.patch(membership._id, { vanishShareReads: share });
    }
    if (share) await catchUp(ctx, membership, roomId);
    return null;
  },
});

/**
 * Call after switching the GLOBAL "share my reads in vanishing chats" on (or
 * changing "seen" away from "nobody") while a vanishing room is open: counts
 * what the caller has already read there. Idempotent; a no-op when they do not
 * share, or when there is nothing to catch up. Other rooms catch up lazily the
 * next time they are opened (markRoomRead does the same catch-up).
 */
export const catchUpVanishReads = mutation({
  args: { roomId: v.id("rooms") },
  returns: v.null(),
  handler: async (ctx, { roomId, userId }) => {
    const membership = await membershipOf(ctx, roomId, userId);
    if (!membership) throw new Error("NOT_A_MEMBER");
    if (await mayShareReads(ctx, userId, membership)) {
      await catchUp(ctx, membership, roomId);
    }
    return null;
  },
});

// ───────────────────────────── queries ───────────────────────────────────

/**
 * What a screen open on a vanishing room needs to draw the countdown ring and
 * the vanish theming: whether vanish is on, the timer, and the pending burn.
 * Members only. Messages with `createdAt <= burnUpTo` vanish at `burnAt`.
 *
 * The burn also takes the slowest reader's OWN messages up to `burnUpTo2`
 * (nobody's message waits for its own sender), but WHO that reader is never
 * leaves the server: naming them would tell the whole room who is holding the
 * chat back, which is read status by another route. So only that reader is
 * told, as `mineUpTo`, about their own messages; on everyone else's screen
 * those few messages still dissolve on time, just without a ring first.
 * Null for a room with no vanish activity.
 * Subscribed to only by open screens; the rooms row is never patched for it.
 */
export const stateForRoom = query({
  args: { roomId: v.id("rooms") },
  returns: v.union(
    v.null(),
    v.object({
      active: v.boolean(),
      afterSeen: v.number(),
      burnAt: v.union(v.number(), v.null()),
      burnUpTo: v.union(v.number(), v.null()),
      mineUpTo: v.union(v.number(), v.null()),
    }),
  ),
  handler: async (ctx, { roomId, userId }) => {
    if (!(await membershipOf(ctx, roomId, userId))) return null;
    const s = await vanishStateOf(ctx, roomId);
    if (!s) return null;
    return {
      active: s.active,
      afterSeen: s.afterSeen,
      burnAt: s.burnAt ?? null,
      burnUpTo: s.burnUpTo ?? null,
      mineUpTo:
        s.burnWho !== undefined && s.burnWho === userId
          ? (s.burnUpTo2 ?? null)
          : null,
    };
  },
});

/**
 * The caller's own sharing choices, for the hidden-seen card and Settings:
 * `perChat` is the room's explicit answer (null = never asked), `global` the
 * "share my reads in vanishing chats" switch, `seen` the raw `visibility.seen`.
 */
export const myVanishPrefs = query({
  args: { roomId: v.id("rooms") },
  returns: v.object({
    perChat: v.union(v.boolean(), v.null()),
    global: v.boolean(),
    seen: v.string(),
    counts: v.boolean(),
  }),
  handler: async (ctx, { roomId, userId }) => {
    const membership = await membershipOf(ctx, roomId, userId);
    if (!membership) throw new Error("NOT_A_MEMBER");
    const user = await ctx.db.get(userId);
    const seen = user?.visibility?.seen ?? "friends";
    const global = user?.visibility?.vanishShareReads === true;
    const perChat = membership.vanishShareReads ?? null;
    return {
      perChat,
      global,
      seen,
      counts: perChat === true || global || seen !== "nobody",
    };
  },
});

// ───────────────────────────── the two jobs ──────────────────────────────

/**
 * The burn: delete what has been seen by everyone it was sent to, `afterSeen`
 * seconds after that point was reached. At most one pending per room
 * (`vanishState.burnJobId`). When it finishes its range it either stops or
 * reschedules itself for the target recorded meanwhile (`nextUpTo`), so every
 * message still gets its full grace.
 *
 * The range is "createdAt <= burnUpTo" (all senders) plus "createdAt <=
 * burnUpTo2, sender burnWho" (the slowest reader's own messages never wait for
 * them). `createdAt + 24h = vanishUntil`, so both are ranges on
 * `by_room_vanish`, bounded below with gt(0).
 */
export const burnVanished = internalMutation({
  args: { roomId: v.id("rooms") },
  returns: v.null(),
  handler: async (ctx, { roomId }) => {
    const state = await vanishStateOf(ctx, roomId);
    if (!state || state.burnUpTo === undefined) return null;
    const now = Date.now();
    // A duplicate that fires before the promised grace must not burn early.
    if (state.burnAt !== undefined && now < state.burnAt - 1000) return null;

    const upTo = state.burnUpTo;
    // Phase 1: everything every recipient has seen.
    const batch = await ctx.db
      .query("messages")
      .withIndex("by_room_vanish", (q) =>
        q.eq("roomId", roomId).gt("vanishUntil", 0).lte("vanishUntil", upTo + VANISH_TTL_MS),
      )
      .take(BURN_BATCH);
    for (const m of batch) {
      await removeMessageAndFanout(ctx, m, m._id, { keepPreview: true });
    }
    if (batch.length === BURN_BATCH) {
      const id = await ctx.scheduler.runAfter(0, internal.vanish.burnVanished, { roomId });
      await ctx.db.patch(state._id, { burnJobId: id });
      return null;
    }

    // Phase 2: the slowest reader's own messages, up to the second cursor.
    let sideWho = state.sideWho;
    let sideDone = state.sideDone;
    const who = state.burnWho;
    const upTo2 = state.burnUpTo2 ?? upTo;
    if (who !== undefined && upTo2 > upTo) {
      const from =
        sideWho?.toString() === who.toString()
          ? Math.max(upTo, sideDone ?? 0)
          : upTo;
      const scan = await ctx.db
        .query("messages")
        .withIndex("by_room_vanish", (q) =>
          q
            .eq("roomId", roomId)
            .gt("vanishUntil", from + VANISH_TTL_MS)
            .lte("vanishUntil", upTo2 + VANISH_TTL_MS),
        )
        .take(SIDE_SCAN);
      for (const m of scan) {
        if (m.userId.toString() === who.toString()) {
          await removeMessageAndFanout(ctx, m, m._id, { keepPreview: true });
        }
      }
      sideWho = who;
      if (scan.length === SIDE_SCAN) {
        sideDone = (scan[scan.length - 1].vanishUntil as number) - VANISH_TTL_MS;
        const id = await ctx.scheduler.runAfter(0, internal.vanish.burnVanished, { roomId });
        await ctx.db.patch(state._id, { sideWho, sideDone, burnJobId: id });
        return null;
      }
      sideDone = upTo2;
    }

    // Done with this target. Hand over to the queued one, if any.
    const patch: Record<string, unknown> = {
      burnUpTo: undefined,
      burnWho: undefined,
      burnUpTo2: undefined,
      burnAt: undefined,
      burnJobId: undefined,
      sideWho,
      sideDone,
    };
    if (state.nextUpTo !== undefined) {
      const at = Math.max(now, (state.nextReachedAt ?? now) + state.afterSeen * 1000);
      const id = await ctx.scheduler.runAt(
        new Date(at),
        internal.vanish.burnVanished,
        { roomId },
      );
      Object.assign(patch, {
        burnUpTo: state.nextUpTo,
        burnWho: state.nextWho,
        burnUpTo2: state.nextUpTo2,
        burnAt: at,
        burnJobId: id,
        nextUpTo: undefined,
        nextWho: undefined,
        nextUpTo2: undefined,
        nextReachedAt: undefined,
      });
    }
    await ctx.db.patch(state._id, patch);
    return null;
  },
});

/**
 * One deadline pass for [state]: delete what reached `vanishUntil`, then point
 * the single deadline job at the oldest survivor. Shared by the job and the
 * daily backstop. [self] is true when called from the job itself, which must
 * not cancel its own id.
 */
export async function runDeadline(
  ctx: any,
  state: any,
  now: number,
  self: boolean,
): Promise<void> {
  const roomId = state.roomId;
  const due = await ctx.db
    .query("messages")
    .withIndex("by_room_vanish", (q: any) =>
      q.eq("roomId", roomId).gt("vanishUntil", 0).lte("vanishUntil", now),
    )
    .take(DEADLINE_BATCH);
  for (const m of due) {
    await removeMessageAndFanout(ctx, m, m._id, { keepPreview: true });
  }

  let at: number;
  if (due.length === DEADLINE_BATCH) {
    at = state.deadlineAt ?? now; // more to do: run again at once
  } else {
    const oldest = await ctx.db
      .query("messages")
      .withIndex("by_room_vanish", (q: any) =>
        q.eq("roomId", roomId).gt("vanishUntil", now),
      )
      .first();
    if (oldest) {
      at = oldest.vanishUntil as number;
    } else if (!state.active) {
      // Nothing left and vanish is off: the chain ends and the row goes. A
      // pending burn would find nothing, so it goes too.
      await cancelJob(ctx, state.burnJobId);
      if (!self) await cancelJob(ctx, state.deadlineJobId);
      await ctx.db.delete(state._id);
      return;
    } else {
      at = now + VANISH_TTL_MS; // idle: one job a day
    }
  }

  if (!self && state.deadlineJobId) await cancelJob(ctx, state.deadlineJobId);
  const id = await ctx.scheduler.runAt(
    new Date(due.length === DEADLINE_BATCH ? now : at),
    internal.vanish.vanishDeadline,
    { roomId, at },
  );
  await ctx.db.patch(state._id, { deadlineJobId: id, deadlineAt: at });
}

/**
 * The 24-hour deadline chain: exactly one job per room. `at` is the instant it
 * was scheduled for and doubles as a token: a job whose `at` no longer matches
 * the row was superseded and does nothing. A message that was burned early is
 * simply not there when this fires, which then moves on to the next survivor
 * or ends the chain.
 */
export const vanishDeadline = internalMutation({
  args: { roomId: v.id("rooms"), at: v.number() },
  returns: v.null(),
  handler: async (ctx, { roomId, at }) => {
    const state = await vanishStateOf(ctx, roomId);
    if (!state || state.deadlineAt !== at) return null;
    await runDeadline(ctx, state, Date.now(), true);
    return null;
  },
});

/**
 * The daily backstop (called from retention.ts, no cron of its own): rooms
 * whose deadline job is an hour overdue lost it. Delete what is past its
 * promise and re-arm the chain. Normally one empty range read a day.
 */
export async function sweepOverdueVanish(ctx: any, now: number): Promise<boolean> {
  const overdue = await ctx.db
    .query("vanishState")
    .withIndex("by_deadline", (q: any) =>
      q.gt("deadlineAt", 0).lt("deadlineAt", now - 60 * 60 * 1000),
    )
    .take(BACKSTOP_PAGE);
  for (const state of overdue) {
    await runDeadline(ctx, state, now, false);
  }
  return overdue.length === BACKSTOP_PAGE;
}
