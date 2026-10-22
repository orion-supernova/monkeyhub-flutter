import { cursorOf, pageAfter, tuning, type Job, type Step } from "../deletionCore";
import { releaseFile } from "../files";
import type { MutationCtx } from "../_generated/server";

/**
 * Custom teardown steps for the `avatar` deletion kind: the work after
 * `users.updateAvatar` swapped a user's picture (`args: { userId, from, to }`).
 *
 * Copies of the old id live on `moments.authorAvatarStorageId` and
 * `momentReactions.userAvatarStorageId` (stamped at write time so the board
 * never reads a `users` row). Each is moved to the user's CURRENT avatar, read
 * live rather than taken from `to`, so two quick changes (A to B to C) converge
 * on C whichever job runs first. Only rows still carrying `from` move: a row
 * stamped before the user had any avatar keeps drawing initials.
 *
 * The old file is deleted by the LAST step, and only when it is not the current
 * avatar (the user may have changed back).
 */

/** The job's user id, or null when the args do not carry a valid one. */
function userIdOf(ctx: MutationCtx, job: Job) {
  const raw = job.args?.userId;
  return typeof raw === "string" ? ctx.db.normalizeId("users", raw) : null;
}

/** The live user's current avatar, or null when the account is gone or going. */
async function currentAvatar(
  ctx: MutationCtx,
  job: Job,
): Promise<{ id: any } | null> {
  const userId = userIdOf(ctx, job);
  if (userId === null) return null;
  const user = await ctx.db.get(userId);
  if (!user || user.deletingAt !== undefined) return null;
  return { id: user.avatarStorageId };
}

/**
 * Walk one table's rows for the user with a `{creation time, id}` cursor (rows
 * stay in range, so a cursor is needed; `pageAfter` does not skip rows created
 * at the same instant) and re-point those carrying `from`.
 */
function repointStep(
  id: string,
  tier: number,
  table: "moments" | "momentReactions",
  field: "authorAvatarStorageId" | "userAvatarStorageId",
): Step {
  return {
    id,
    tier,
    async run(ctx, job, b) {
      const userId = userIdOf(ctx, job);
      const from = job.args?.from;
      if (userId === null || !from) return { done: true };
      const cur = await currentAvatar(ctx, job);
      b.read();
      // Gone user: their rows go with them. Back to `from`: nothing to move.
      if (cur === null || cur.id === undefined || cur.id.toString() === from) {
        return { done: true };
      }
      let cursor = job.cursor;
      for (;;) {
        if (b.spent()) return { done: false, cursor };
        const rows: any[] = await pageAfter(
          (t, k) =>
            (ctx.db.query(table) as any)
              .withIndex("by_user", (q: any) =>
                q.eq("userId", userId).gte("_creationTime", t),
              )
              .take(k),
          cursor,
          tuning.pageRows,
        );
        b.read(Math.max(rows.length, 1));
        if (rows.length === 0) return { done: true };
        for (const row of rows) {
          if (b.spent()) return { done: false, cursor };
          if (row[field]?.toString() === from) {
            await ctx.db.patch(row._id, { [field]: cur.id });
            b.write();
          }
          cursor = cursorOf(row);
        }
      }
    },
  };
}

export const avatarSteps: Step[] = [
  repointStep("moments", 10, "moments", "authorAvatarStorageId"),
  repointStep("reactions", 20, "momentReactions", "userAvatarStorageId"),
  {
    id: "deleteOld",
    tier: 100,
    async run(ctx, job, b) {
      const from = job.args?.from;
      if (!from) return { done: true };
      const cur = await currentAvatar(ctx, job);
      b.read();
      // A release with no ref left is a no-op, so a re-run is safe.
      if (cur === null || cur.id?.toString() !== from) {
        await releaseFile(ctx, from, {
          table: "users",
          id: job.args?.userId,
          field: "avatarStorageId",
        });
        b.write(5);
      }
      return { done: true };
    },
  },
];
