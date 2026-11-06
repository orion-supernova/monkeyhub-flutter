import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalQuery } from "./_generated/server";
import { internalMutation } from "./dbHooks";

/**
 * Strips what the 2026-11 backend cleanup left behind in the data, so a LATER
 * deploy can delete it from the schema (a push whose schema omits a field that
 * is still on disk is rejected).
 *
 * TWO-DEPLOY ORDER
 *
 *   Before deploy 1, on the code that is live today (these functions are not
 *   there yet): re-check `profileMigrations:countCopies` is 0 on all nine copy
 *   tables, `presenceMigrations:countUsersWithPresenceFields` is 0. Anything
 *   written since the last strip (the diagnostics and moderation rooms stamped
 *   `messages.senderName` until this deploy) fails the push: re-run
 *   `profileMigrations:stripCopies` for that table first.
 *
 *   Deploy 1 (this code). The schema no longer lists `users.status/lastSeen`
 *   or any profile copy field; it still lists, as OPTIONAL, every legacy
 *   `roomMembers` field and the `receiptLogs` table, and the `deletions.kind`
 *   literal "avatar". Nothing reads or writes them any more. Then, from backend/:
 *
 *     npx convex run cleanupMigration:stripLegacy '{}'
 *       Paged, self-chaining, idempotent. Phase 1 unsets the legacy fields on
 *       every `roomMembers` row, phase 2 deletes every `receiptLogs` row,
 *       phase 3 deletes leftover `deletions` rows of the retired `avatar`
 *       kind. Watch `npx convex logs` for "cleanupMigration.stripLegacy done".
 *     npx convex run cleanupMigration:countLegacy '{}'
 *       One page per call (pass `phase` and the returned `continueCursor`
 *       until `isDone`, for each phase). Every `carrying` must sum to 0.
 *
 *   Deploy 2. Only after the counts are 0: delete the legacy fields from
 *   `roomMembers`, the `receiptLogs` table (and its `referenceRules` entries),
 *   the "avatar" literal in `deletions.kind`, then this module and the
 *   modules that read the legacy fields (`roomStateMigration.ts`,
 *   `profileMigrations.ts` stays). Doing it first fails schema validation on
 *   the existing rows.
 *
 * Rolling back to code that reads the legacy `roomMembers` fields is not
 * possible once phase 1 has run: their only copy is gone.
 */

/** Everything C1 moved off `roomMembers` (now on `roomUserState` / `roomReceipts` / `receiptMoves`). */
export const LEGACY_MEMBER_FIELDS = [
  "lastReadAt",
  "lastDeliveredAt",
  "lastReadClock",
  "lastDeliveredClock",
  "readLog",
  "deliveredLog",
  "isPinned",
  "pinnedAt",
  "isArchived",
  "archivedAt",
  "muteNotifications",
  "muteBadges",
  "mutedUntil",
  "seenVisibility",
  "vanishSeenAt",
  "vanishShareReads",
] as const;

/** Membership rows per page: legacy rows carry up to ~8 KB of logs. */
export const MEMBER_PAGE = 50;
/** Rows deleted per tick in the delete phases. */
export const DELETE_PAGE = 100;

const phaseArg = v.union(
  v.literal("members"),
  v.literal("receiptLogs"),
  v.literal("avatarJobs"),
);
type Phase = "members" | "receiptLogs" | "avatarJobs";
const NEXT: Record<Phase, Phase | null> = {
  members: "receiptLogs",
  receiptLogs: "avatarJobs",
  avatarJobs: null,
};

/** The legacy fields a membership row still carries. */
function legacyFieldsOf(row: any): string[] {
  return LEGACY_MEMBER_FIELDS.filter((f) => row[f] !== undefined);
}

export const stripLegacy = internalMutation({
  args: {
    phase: v.optional(phaseArg),
    cursor: v.optional(v.union(v.string(), v.null())),
    /** Running totals, carried between self-scheduled ticks. */
    stripped: v.optional(v.number()),
    deletedLogs: v.optional(v.number()),
    deletedJobs: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const phase: Phase = args.phase ?? "members";
    let stripped = args.stripped ?? 0;
    let deletedLogs = args.deletedLogs ?? 0;
    let deletedJobs = args.deletedJobs ?? 0;
    const totals = () => ({ stripped, deletedLogs, deletedJobs });
    const chain = async (
      next: { phase: Phase; cursor?: string | null },
    ): Promise<void> => {
      await ctx.scheduler.runAfter(0, internal.cleanupMigration.stripLegacy, {
        ...next,
        ...totals(),
      });
    };

    let more = false;
    let cursor: string | null = null;
    if (phase === "members") {
      const page = await ctx.db
        .query("roomMembers")
        .paginate({ cursor: args.cursor ?? null, numItems: MEMBER_PAGE });
      for (const row of page.page) {
        const fields = legacyFieldsOf(row);
        // Already clean: no write.
        if (fields.length === 0) continue;
        await ctx.db.patch(
          row._id,
          Object.fromEntries(fields.map((f) => [f, undefined])) as any,
        );
        stripped++;
      }
      more = !page.isDone;
      cursor = page.isDone ? null : page.continueCursor;
    } else if (phase === "receiptLogs") {
      // Deleted rows leave the range, so each tick starts from the top.
      const rows = await ctx.db.query("receiptLogs").take(DELETE_PAGE);
      for (const r of rows) await ctx.db.delete(r._id);
      deletedLogs += rows.length;
      more = rows.length === DELETE_PAGE;
    } else {
      const rows = await ctx.db
        .query("deletions")
        .withIndex("by_target", (q) => q.eq("kind", "avatar"))
        .take(DELETE_PAGE);
      for (const r of rows) await ctx.db.delete(r._id);
      deletedJobs += rows.length;
      more = rows.length === DELETE_PAGE;
    }

    if (more) {
      await chain({ phase, cursor });
      return { done: false, phase, ...totals() };
    }
    const next = NEXT[phase];
    if (next !== null) {
      await chain({ phase: next, cursor: null });
      return { done: false, phase: next, ...totals() };
    }
    console.log(
      `cleanupMigration.stripLegacy done: ${stripped} membership rows stripped, ` +
        `${deletedLogs} receiptLogs rows deleted, ${deletedJobs} avatar jobs deleted`,
    );
    return { done: true, phase, ...totals() };
  },
});

/**
 * One page of what `stripLegacy` has not cleaned yet, for one phase (default
 * `members`). Sum `carrying` over pages until `isDone`, for each phase; all
 * three must reach 0 before deploy 2. `byField` (members) names the fields
 * still present and how many rows hold each.
 */
export const countLegacy = internalQuery({
  args: {
    phase: v.optional(phaseArg),
    cursor: v.optional(v.union(v.string(), v.null())),
    numItems: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const phase: Phase = args.phase ?? "members";
    const opts = { cursor: args.cursor ?? null, numItems: args.numItems ?? 200 };
    if (phase === "members") {
      const page = await ctx.db.query("roomMembers").paginate(opts);
      let carrying = 0;
      const byField: Record<string, number> = {};
      for (const row of page.page) {
        const fields = legacyFieldsOf(row);
        if (fields.length === 0) continue;
        carrying++;
        for (const f of fields) byField[f] = (byField[f] ?? 0) + 1;
      }
      return {
        phase,
        scanned: page.page.length,
        carrying,
        byField,
        isDone: page.isDone,
        continueCursor: page.continueCursor,
      };
    }
    const page =
      phase === "receiptLogs"
        ? await ctx.db.query("receiptLogs").paginate(opts)
        : await ctx.db
            .query("deletions")
            .withIndex("by_target", (q) => q.eq("kind", "avatar"))
            .paginate(opts);
    return {
      phase,
      scanned: page.page.length,
      carrying: page.page.length,
      byField: {} as Record<string, number>,
      isDone: page.isDone,
      continueCursor: page.continueCursor,
    };
  },
});
