import { v } from "convex/values";
import { mutation, query } from "./functions";
import {
  ERR_AGE_ALREADY_SET,
  ageBand,
  ageInYears,
  ageNeeded,
  assertValidBirth,
} from "./ageCore";
import { restrictForAge } from "./moderation";

/**
 * The age sheet for accounts that never gave an age: everyone who signed up
 * before 2026-11-17, and anyone an old build signed up without the age step.
 * Same shape as `terms.ts`: [status] decides whether the app shows the sheet,
 * [submit] answers it. Rules: `ageCore.ts`.
 */

/** Whether the caller still owes the age question. One `get` by id. */
export const status = query({
  args: {},
  returns: v.object({ needed: v.boolean() }),
  handler: async (ctx, { userId }) => {
    const me = await ctx.db.get(userId);
    return { needed: me !== null && ageNeeded(me) };
  },
});

/**
 * Records the caller's birth year and month, once. 13 or over: stored, done.
 * Under 13: stored, and the account is restricted (`moderation.restrictForAge`),
 * which revokes this very session; the app reads `restricted` and signs out to
 * the paused notice. A second call answers AGE_ALREADY_SET: the age is locked,
 * and only staff can change it.
 */
export const submit = mutation({
  args: { birthYear: v.number(), birthMonth: v.number() },
  returns: v.object({ restricted: v.boolean() }),
  handler: async (ctx, { userId, birthYear, birthMonth }) => {
    const me = await ctx.db.get(userId);
    if (!me) throw new Error("USER_NOT_FOUND");
    if (!ageNeeded(me)) throw new Error(ERR_AGE_ALREADY_SET);
    const now = Date.now();
    assertValidBirth(birthYear, birthMonth, now);
    await ctx.db.patch(userId, { birthYear, birthMonth, ageGivenAt: now });
    const restricted = ageBand(ageInYears(birthYear, birthMonth, now)) !== "ok";
    if (restricted) await restrictForAge(ctx, userId);
    return { restricted };
  },
});
