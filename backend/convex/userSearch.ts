import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { isSystemAccount } from "./systemAccount";

/**
 * The text `users.searchName` holds and `search_users` indexes: the handle and
 * the display name, lowercased and space-joined. One field, so one search
 * index covers both. Every write of `users.name` / `users.username` must set
 * `searchName: searchNameOf(...)` in the same patch or insert (auth.signup,
 * family.createChild, socialAuth.createWithIdentity, users.updateProfile,
 * users.applyUsernameChange). System accounts are never searchable and skip it.
 */
export function searchNameOf(username: string, name?: string | null): string {
  return `${username} ${name ?? ""}`.trim().toLowerCase();
}

const PAGE = 200;

/**
 * One-off backfill of `users.searchName` for rows written before the field
 * existed. Idempotent (patches only a row whose value differs), resumable and
 * self-chaining. Skips accounts being deleted and system accounts, neither of
 * which is searchable. Run:
 *
 *     npx convex run userSearch:backfillSearchName '{}'
 *
 * It returns the first page's counts; the rest chains through the scheduler
 * and logs the totals when the table is exhausted.
 */
export const backfillSearchName = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    scanned: v.optional(v.number()),
    patched: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, scanned, patched }) => {
    const page = await ctx.db
      .query("users")
      .paginate({ numItems: PAGE, cursor: cursor ?? null });
    let s = scanned ?? 0;
    let p = patched ?? 0;
    for (const u of page.page) {
      s++;
      if (u.deletingAt !== undefined) continue;
      if (isSystemAccount(u)) continue;
      const want = searchNameOf(u.username, u.name);
      if (u.searchName === want) continue;
      await ctx.db.patch(u._id, { searchName: want });
      p++;
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.userSearch.backfillSearchName, {
        cursor: page.continueCursor,
        scanned: s,
        patched: p,
      });
    } else {
      console.log(`backfillSearchName: scanned ${s}, patched ${p}`);
    }
    return { scanned: s, patched: p, done: page.isDone };
  },
});
