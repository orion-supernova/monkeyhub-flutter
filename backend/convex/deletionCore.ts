/**
 * The lifecycle engine for deletes: shared types, budgets, tombstone helpers and
 * the bounded first transaction (docs/data-integrity-phase2-design.md).
 *
 * Deleting a user or a room is too big for one transaction, so it is split:
 *
 *  1. `startUserDeletion` / `startRoomDeletion` run in the caller's mutation and
 *     do a BOUNDED amount of work: close the gates (tombstone, scrub, revoke),
 *     insert a `deletions` job and schedule its first step.
 *  2. `deletions.step` then walks the kind's plan (`deletionPlans.planFor`) a
 *     page at a time, deleting the parent row last.
 *
 * Only `users` and `rooms` get a tombstone (`deletingAt`): their ids are
 * referenced everywhere and must keep resolving until the end. Readers that
 * hold the row already check `isTombstoned`; the rest go through `getLive*`.
 *
 * There is no time budget: `Date.now()` is frozen inside a mutation, so a
 * `Budget` counts reads and writes instead.
 */
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import { retireIfStaff } from "./retiredHandles";
import { identityBanHash } from "./sessionCore";

export type DeletionKind = Doc<"deletions">["kind"];
export type Job = Doc<"deletions">;

export interface StepResult {
  /** True when the step's range is empty and the plan may move on. */
  done: boolean;
  /** Where to resume when not done; `null`/absent for steps that re-query. */
  cursor?: string | null;
}

export interface Step {
  /** Unique within a kind's plan; persisted on the job as `stepId`. */
  id: string;
  /** Plan order, ascending. Generic steps are 50; the parent row is 1000. */
  tier: number;
  /** `REFERENCE_RULES` keys this step handles, so no generic step runs for them. */
  claims?: string[];
  /**
   * Do one bounded slice. Must be idempotent (a re-run is a no-op, a crash
   * mid-way is safe) and must return `done: false` once `b.spent()`.
   */
  run(ctx: MutationCtx, job: Job, b: Budget): Promise<StepResult>;
}

/**
 * Knobs. Tests shrink them to force several pages from a handful of rows, so
 * read them when a budget is built, not at import time.
 */
export const tuning = {
  /** Writes per transaction. */
  maxWrites: 1500,
  /** Document reads per transaction (Convex allows 16k; stay far under). */
  maxReads: 6000,
  /** Rows per index probe. */
  pageRows: 100,
  /** Per-table cap for work done inline in a user-facing mutation. */
  inlineCap: 25,
};

/** Counts the work a step transaction has done; steps check `spent()` between rows. */
export class Budget {
  reads = 0;
  writes = 0;
  readonly maxReads: number;
  readonly maxWrites: number;

  constructor(maxWrites = tuning.maxWrites, maxReads = tuning.maxReads) {
    this.maxWrites = maxWrites;
    this.maxReads = maxReads;
  }

  read(n = 1): void {
    this.reads += n;
  }

  write(n = 1): void {
    this.writes += n;
  }

  spent(): boolean {
    return this.writes >= this.maxWrites || this.reads >= this.maxReads;
  }
}

/** Hooks for tests; always empty in production. */
export const testHooks: {
  /** Called before every step runs; throw to simulate a failing step. */
  beforeStep?: (ctx: MutationCtx, job: Job, step: Step) => Promise<void> | void;
} = {};

// ── Tombstones ──────────────────────────────────────────────────────────────

export function isTombstoned(
  row: { deletingAt?: number } | null | undefined,
): boolean {
  return row?.deletingAt !== undefined;
}

/** The room, or null when it is gone or being deleted. */
export async function getLiveRoom(
  ctx: QueryCtx | MutationCtx,
  roomId: Id<"rooms">,
): Promise<Doc<"rooms"> | null> {
  const room = await ctx.db.get(roomId);
  return room !== null && !isTombstoned(room) ? room : null;
}

/** The user, or null when they are gone or being deleted. */
export async function getLiveUser(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
): Promise<Doc<"users"> | null> {
  const user = await ctx.db.get(userId);
  return user !== null && !isTombstoned(user) ? user : null;
}

// ── Capped inline deletes ───────────────────────────────────────────────────

/**
 * Delete up to `cap` rows of `query` and say whether more were left, so a
 * user-facing mutation does bounded work and hands the rest to a job.
 */
export async function deleteCapped(
  ctx: MutationCtx,
  query: { take(n: number): Promise<{ _id: Id<any> }[]> },
  cap: number = tuning.inlineCap,
): Promise<{ deleted: number; overflow: boolean }> {
  const rows = await query.take(cap + 1);
  const batch = rows.slice(0, cap);
  for (const row of batch) await ctx.db.delete(row._id);
  return { deleted: batch.length, overflow: rows.length > cap };
}

// ── Jobs ────────────────────────────────────────────────────────────────────

export interface EnqueueOptions {
  kind: DeletionKind;
  targetId: string;
  args?: Record<string, any>;
  reason?: string;
}

/**
 * Insert a job and schedule its first step. A running job for the same
 * `[kind, targetId]` is returned as it is, so a double tap makes one job.
 */
export async function enqueueDeletion(
  ctx: MutationCtx,
  opts: EnqueueOptions,
): Promise<Id<"deletions">> {
  const latest = await ctx.db
    .query("deletions")
    .withIndex("by_target", (q) =>
      q.eq("kind", opts.kind).eq("targetId", opts.targetId),
    )
    .order("desc")
    .take(10);
  const running = latest.find((j) => j.state === "running");
  if (running) return running._id;

  const now = Date.now();
  const jobId = await ctx.db.insert("deletions", {
    kind: opts.kind,
    targetId: opts.targetId,
    state: "running",
    stepId: "",
    cursor: null,
    ...(opts.args !== undefined ? { args: opts.args } : {}),
    ...(opts.reason !== undefined ? { reason: opts.reason } : {}),
    createdAt: now,
    lastProgressAt: now,
    restarts: 0,
    attempts: 0,
    pages: 0,
    writes: 0,
  });
  await ctx.scheduler.runAfter(0, internal.deletions.step, { jobId: jobId, gen: 0 });
  return jobId;
}

/** Live sessions revoked in the first transaction; the first step does the rest. */
const FIRST_TX_SESSIONS = 100;
/** A user has a handful of provider identities at most. */
const FIRST_TX_IDENTITIES = 20;

/**
 * Close every gate on a user in one bounded transaction (about 100 writes at
 * most) and queue the rest. Null when the account is already gone. A running job
 * is returned as it is, so a double tap is harmless.
 *
 * Staying in the caller: `auth.deleteAccount` runs its LAST_GUARDIAN check
 * BEFORE calling this.
 */
export async function startUserDeletion(
  ctx: MutationCtx,
  userId: Id<"users">,
  opts: { reason?: string } = {},
): Promise<Id<"deletions"> | null> {
  const user = await ctx.db.get(userId);
  if (user === null) return null;

  const existing = await ctx.db
    .query("deletions")
    .withIndex("by_target", (q) => q.eq("kind", "user").eq("targetId", userId))
    .order("desc")
    .take(10);
  const running = existing.find((j) => j.state === "running");
  if (running) return running._id;

  const suspended = user.suspendedAt !== undefined;
  const args: Record<string, any> = { suspended };
  if (user.avatarStorageId !== undefined) args.avatarStorageId = user.avatarStorageId;

  if (!isTombstoned(user)) {
    // The handle of a staff account must never become free (it carries rights).
    await retireIfStaff(ctx, user.username);

    // Scrub: the row stays (every reader still resolves the id) but holds
    // nothing about the person. `suspendedAt` stays so the ban survives.
    await ctx.db.patch(userId, {
      deletingAt: Date.now(),
      username: `deleted:${userId}`,
      name: undefined,
      email: undefined,
      recoveryKeyHash: undefined,
      lastSeen: undefined,
      passwordHash: "",
      status: "offline",
      avatarStorageId: undefined,
      // Legacy push tokens on the row itself: a ghost must not ring.
      voipToken: undefined,
      fcmToken: undefined,
    });

    // Revoke rather than delete, so a device's next call gets SESSION_REVOKED.
    // `requireSession` also refuses a tombstone, so any left over are dead too.
    const now = Date.now();
    const sessions = await ctx.db
      .query("sessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .take(FIRST_TX_SESSIONS);
    for (const row of sessions) {
      if (row.revokedAt === undefined) await ctx.db.patch(row._id, { revokedAt: now });
    }

    // The (provider, subject) row is what sign-in looks up: leaving it would let
    // that Apple ID into a ghost. A suspended account may delete itself, but
    // must not shed the ban, so remember a hash of each identity. Apple needs
    // the grant revoked (fetch, so scheduled), passed by value as the row goes.
    const identities = await ctx.db
      .query("socialIdentities")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .take(FIRST_TX_IDENTITIES);
    for (const identity of identities) {
      if (suspended) {
        await ctx.db.insert("bannedIdentities", {
          hash: await identityBanHash(identity.provider, identity.subject),
          createdAt: Date.now(),
        });
      }
      if (identity.appleRefreshToken) {
        await ctx.scheduler.runAfter(0, internal.socialAuth.revokeAppleGrant, {
          refreshToken: identity.appleRefreshToken,
        });
      }
      await ctx.db.delete(identity._id);
    }
  }

  return await enqueueDeletion(ctx, {
    kind: "user",
    targetId: userId,
    args,
    reason: opts.reason,
  });
}

/**
 * Hide a room at once and queue its teardown (about 3 writes). The rename takes
 * it out of every `by_name` lookup and `listPublic`, frees the name for a
 * re-created DM pair and drops it from `findDmRoomsBetween`; no reader needs a
 * new read. Null when the room is already gone.
 */
export async function startRoomDeletion(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  opts: { reason?: string } = {},
): Promise<Id<"deletions"> | null> {
  const room = await ctx.db.get(roomId);
  if (room === null) return null;

  const existing = await ctx.db
    .query("deletions")
    .withIndex("by_target", (q) => q.eq("kind", "room").eq("targetId", roomId))
    .order("desc")
    .take(10);
  const running = existing.find((j) => j.state === "running");
  if (running) return running._id;

  const args: Record<string, any> = {};
  if (room.avatarStorageId !== undefined) args.avatarStorageId = room.avatarStorageId;
  if (room.system !== undefined) args.system = room.system;

  if (!isTombstoned(room)) {
    await ctx.db.patch(roomId, {
      deletingAt: Date.now(),
      name: `deleted:${roomId}`,
      isPrivate: true,
      passwordHash: undefined,
    });
  }

  return await enqueueDeletion(ctx, {
    kind: "room",
    targetId: roomId,
    args,
    reason: opts.reason,
  });
}
