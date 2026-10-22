// Point-probe privacy check, for hot subscriptions.
//
// `visibility.lensFor` scans ALL of the viewer's friendships and wards once per
// call, which is the right price for a list screen and the wrong one for
// `presenceApi.forUsers`, which re-runs on every presence transition among the
// ids it watches. `canSeeAs` answers one (viewer, subject, field) question
// with at most three indexed point reads, so a 100-id subscription is bounded
// at ~300 reads however many friends the viewer has.
//
// It must agree with `visibility.ts` (levels, defaults, the guardian bypass);
// it takes the subject's LEVEL as an argument instead of a users row, because
// presence keeps its own copy of the levels and `users` is never read. This
// module imports `visibility.ts` for a TYPE only (erased at build time), so it
// cannot cycle with it.
import type { VisField } from "./visibility";

/** Mirror of `visibility.ts` GUARDIAN_BYPASS. Keep the two in step. */
const GUARDIAN_BYPASS: ReadonlySet<VisField> = new Set<VisField>([
  "avatar",
  "status",
  "lastSeen",
]);

/** Mirror of `visibility.ts` DEFAULT_LEVEL, for callers holding an absent level. */
export const DEFAULT_POINT_LEVEL: Record<VisField, string> = {
  avatar: "public",
  status: "friends",
  lastSeen: "friends",
  seen: "friends",
};

/** An accepted friendship in either direction, via two `by_pair` probes. */
export async function areFriends(ctx: any, a: any, b: any): Promise<boolean> {
  const ab = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) => q.eq("userId", a).eq("friendId", b))
    .first();
  if (ab?.status === "accepted") return true;
  const ba = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) => q.eq("userId", b).eq("friendId", a))
    .first();
  return ba?.status === "accepted";
}

/**
 * May [viewerId] see [subjectId]'s [field], given the subject's stored
 * [level] (`undefined` = the field's default)?
 *
 * Order, cheapest first: self, "public", guardian bypass, friends, else no.
 * A null/undefined viewer (anonymous) sees "public" only.
 */
export async function canSeeAs(
  ctx: any,
  viewerId: any,
  subjectId: any,
  level: string | undefined,
  field: VisField,
): Promise<boolean> {
  const effective = level ?? DEFAULT_POINT_LEVEL[field];
  if (viewerId && viewerId.toString() === subjectId?.toString()) return true;
  if (effective === "public") return true;
  if (!viewerId) return false;
  if (GUARDIAN_BYPASS.has(field)) {
    const g = await ctx.db
      .query("guardianships")
      .withIndex("by_pair", (q: any) =>
        q.eq("guardianId", viewerId).eq("childId", subjectId),
      )
      .first();
    if (g) return true;
  }
  if (effective === "friends") return await areFriends(ctx, viewerId, subjectId);
  return false; // "nobody" (or anything unknown)
}
