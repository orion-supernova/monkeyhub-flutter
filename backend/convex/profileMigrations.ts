// Phase 6 profile migrations (stages W1 and W3+ of the rollout).
//
//   backfillProfiles   W1. Calls `syncProfile` for every user, so each one has
//                      a `profiles` row (a tombstone for a deleted account).
//                      A no-op write when the row is already right, so it is
//                      idempotent and safe next to live writers.
//   stripCopies        After W3. Per table, clears the denormalised name/avatar
//                      copies. Refuses to run while copies are on (`profileCopyGate.copiesOn()`).
//   countMissingProfiles / countCopies   progress counters, all reach 0.
//
// Every function walks one table with a single `.paginate` and chains itself
// with the scheduler, so each page is its own small transaction.
//
// Never touched: `messages.mentions[].username`, call/push payloads, game
// names (`matches.seats[].name`, `seatRequest.name`, `gameChallenges.name`),
// `roomMembers.seenVisibility`.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation, internalQuery } from "./_generated/server";
import { syncProfile } from "./profilesCore";
import { copiesOn } from "./profileCopyGate";

/** Users per backfill page: one user get, one profile probe, <= 1 write each. */
export const BACKFILL_PAGE = 100;
/** Rows per strip tick. Each patch wakes that row's subscribers. */
export const STRIP_PAGE = 100;
/** Pause between strip ticks that wrote something. */
export const STRIP_TICK_MS = 2_000;
/** Rows per counting page (read only). */
export const COUNT_PAGE = 200;

/** Tables that carry copy fields, in the order the runbook strips them. */
export const COPY_TABLES = [
  "messages",
  "messageInteractions",
  "interactionResponses",
  "moments",
  "momentReactions",
  "momentComments",
  "momentCommentReactions",
  "recordReactions",
  "typingIndicators",
] as const;
export type CopyTable = (typeof COPY_TABLES)[number];

const tableArg = v.union(...COPY_TABLES.map((t) => v.literal(t)));
const cursorArg = v.optional(v.union(v.string(), v.null()));

const has = (row: any, ...fields: string[]) => fields.some((f) => row[f] !== undefined);

/**
 * The patch that removes this row's copies, or null when it carries none.
 * Only copy fields appear in a patch (`undefined` deletes the field).
 */
export function copyPatch(table: CopyTable, row: any): Record<string, unknown> | null {
  switch (table) {
    case "messages": {
      const patch: Record<string, unknown> = {};
      if (row.senderName !== undefined) patch.senderName = undefined;
      if (row.replyToPreview && "senderName" in row.replyToPreview) {
        const { senderName: _drop, ...rest } = row.replyToPreview;
        patch.replyToPreview = rest;
      }
      return Object.keys(patch).length ? patch : null;
    }
    case "messageInteractions": {
      if (!Array.isArray(row.choices)) return null;
      let dirty = false;
      const choices = row.choices.map((c: any) => {
        if (!Array.isArray(c.respondents)) return c;
        let hit = false;
        const respondents = c.respondents.map((r: any) => {
          if (!("name" in r)) return r;
          hit = true;
          const { name: _drop, ...rest } = r;
          return rest;
        });
        if (!hit) return c;
        dirty = true;
        return { ...c, respondents };
      });
      return dirty ? { choices } : null;
    }
    case "interactionResponses":
      return has(row, "userName") ? { userName: undefined } : null;
    case "moments":
      return has(row, "authorName", "authorUsername", "authorAvatarStorageId")
        ? { authorName: undefined, authorUsername: undefined, authorAvatarStorageId: undefined }
        : null;
    case "momentReactions":
      return has(row, "userName", "userUsername", "userAvatarStorageId", "userAvatarLevel")
        ? {
            userName: undefined,
            userUsername: undefined,
            userAvatarStorageId: undefined,
            userAvatarLevel: undefined,
          }
        : null;
    case "momentComments":
      return has(row, "userName", "replyToName")
        ? { userName: undefined, replyToName: undefined }
        : null;
    case "momentCommentReactions":
    case "recordReactions":
      return has(row, "userName") ? { userName: undefined } : null;
    case "typingIndicators":
      return has(row, "userName", "avatarStorageId", "avatarVisibility")
        ? { userName: undefined, avatarStorageId: undefined, avatarVisibility: undefined }
        : null;
  }
}

export const backfillProfiles = internalMutation({
  args: {
    cursor: cursorArg,
    numItems: v.optional(v.number()),
    changed: v.optional(v.number()),
    unchanged: v.optional(v.number()),
    pages: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? BACKFILL_PAGE });

    let changed = args.changed ?? 0;
    let unchanged = args.unchanged ?? 0;
    for (const user of page.page) {
      // syncProfile builds a tombstone for a user marked `deletingAt`.
      const r = await syncProfile(ctx, user._id);
      if (r.changed) changed++;
      else unchanged++;
    }

    const pages = (args.pages ?? 0) + 1;
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.profileMigrations.backfillProfiles, {
        cursor: page.continueCursor,
        numItems: args.numItems,
        changed,
        unchanged,
        pages,
      });
    } else {
      console.log(`backfillProfiles done: written=${changed} alreadyRight=${unchanged} pages=${pages}`);
    }
    return { done: page.isDone, changed, unchanged, pages };
  },
});

export const stripCopies = internalMutation({
  args: {
    table: tableArg,
    cursor: cursorArg,
    numItems: v.optional(v.number()),
    stripped: v.optional(v.number()),
    pages: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    if (copiesOn()) {
      throw new Error(
        "stripCopies refused: PROFILE_COPIES is still true (stage W3). Old builds still read the copies.",
      );
    }
    const page = await (ctx.db as any)
      .query(args.table)
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? STRIP_PAGE });

    let stripped = args.stripped ?? 0;
    const before = stripped;
    for (const row of page.page) {
      // Already clean: no write, so no subscriber wakes.
      const patch = copyPatch(args.table, row);
      if (!patch) continue;
      await ctx.db.patch(row._id, patch as any);
      stripped++;
    }

    const pages = (args.pages ?? 0) + 1;
    if (!page.isDone) {
      // A page that wrote nothing woke nobody, so the next one goes straight on.
      const pause = stripped > before ? STRIP_TICK_MS : 0;
      await ctx.scheduler.runAfter(pause, internal.profileMigrations.stripCopies, {
        table: args.table,
        cursor: page.continueCursor,
        numItems: args.numItems,
        stripped,
        pages,
      });
    } else {
      console.log(`stripCopies ${args.table} done: stripped=${stripped} pages=${pages}`);
    }
    return { done: page.isDone, stripped, pages };
  },
});

/** One page of "users with no profile row". Add up `missing` until `isDone`. */
export const countMissingProfiles = internalQuery({
  args: { cursor: cursorArg, numItems: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? COUNT_PAGE });
    let missing = 0;
    for (const user of page.page) {
      const row = await ctx.db
        .query("profiles")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .first();
      if (!row) missing++;
    }
    return { missing, scanned: page.page.length, isDone: page.isDone, continueCursor: page.continueCursor };
  },
});

/** One page of "rows in `table` still carrying a copy field". */
export const countCopies = internalQuery({
  args: { table: tableArg, cursor: cursorArg, numItems: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const page = await (ctx.db as any)
      .query(args.table)
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? COUNT_PAGE });
    let carrying = 0;
    for (const row of page.page) if (copyPatch(args.table, row)) carrying++;
    return { carrying, scanned: page.page.length, isDone: page.isDone, continueCursor: page.continueCursor };
  },
});
