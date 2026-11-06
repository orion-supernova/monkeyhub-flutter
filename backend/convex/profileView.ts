// B6: the people-shaped payloads of friends, rooms and family, built from the
// `profiles` and `presence` side tables so a subscription never reads (and
// never re-runs on) a whole `users` row (handbook R2).
//
// The privacy rule is the one in visibility.ts (self, guardian bypass, level);
// here the LEVELS come from the copies on the side-table rows
// (`profiles.avatarLevel`, `presence.statusLevel/lastSeenLevel`) and the
// relationship comes from a lens the caller already holds.
import { childrenOf } from "./childGuard";
import { isSystemAccount } from "./systemAccount";
import type { VisField } from "./visibility";
import { DEFAULT_POINT_LEVEL } from "./visibilityPoint";

/** The relationship half of a PrivacyLens (a PrivacyLens satisfies it). */
export type Rel = {
  isSelf(id: any): boolean;
  isFriend(id: any): boolean;
  isGuardian(id: any): boolean;
};

const BYPASS: ReadonlySet<VisField> = new Set<VisField>(["avatar", "status", "lastSeen"]);

/** May the viewer see [field] of [subjectId] at the stored [level]? */
export function canSeeLevel(
  rel: Rel,
  subjectId: any,
  level: string | undefined,
  field: VisField,
): boolean {
  if (rel.isSelf(subjectId)) return true;
  if (rel.isGuardian(subjectId) && BYPASS.has(field)) return true;
  const eff = level ?? DEFAULT_POINT_LEVEL[field];
  if (eff === "public") return true;
  if (eff === "friends") return rel.isFriend(subjectId);
  return false;
}

/**
 * Relationship for a viewer whose accepted friends are already known (the
 * rows listFriends has read), with one guardianships scan for their wards.
 */
export async function relFromFriends(
  ctx: any,
  viewerId: any,
  friendIds: Iterable<any>,
): Promise<Rel> {
  const friends = new Set<string>([...friendIds].map((x) => x.toString()));
  const wards = new Set<string>((await childrenOf(ctx, viewerId)).map((x: any) => x.toString()));
  const me = viewerId.toString();
  return {
    isSelf: (id) => id?.toString() === me,
    isFriend: (id) => friends.has(id?.toString()),
    isGuardian: (id) => wards.has(id?.toString()),
  };
}

export async function profileOf(ctx: any, userId: any) {
  return await ctx.db
    .query("profiles")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

export async function presenceOf(ctx: any, userId: any) {
  return await ctx.db
    .query("presence")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

/** The profile a `users` row implies; only for an account not yet backfilled. */
function profileLikeOfUser(u: any) {
  return {
    userId: u._id,
    name: u.name ?? u.username,
    username: u.username,
    avatarStorageId: u.avatarStorageId,
    avatarLevel: u.visibility?.avatar,
    feedLevels: undefined,
    deleted: u.deletingAt !== undefined ? true : undefined,
    isSystem: isSystemAccount(u) ? true : undefined,
  };
}

/**
 * The profile row of [userId], or (until `backfillProfiles` has made it) the
 * profile its `users` row implies. null when neither exists.
 */
export async function profileOrUser(ctx: any, userId: any) {
  const p = await profileOf(ctx, userId);
  if (p) return p;
  const u = await ctx.db.get(userId);
  return u ? profileLikeOfUser(u) : null;
}

/**
 * A `users`-row-shaped stand-in built from a profile, for code that runs
 * `lens.canSee(row, "avatar")`, `visibilityOf(row)` or `identityOfRow(row)`.
 * It carries no secrets and no presence.
 */
export function userLikeOfProfile(p: any) {
  return {
    _id: p.userId,
    username: p.username,
    name: p.name,
    avatarStorageId: p.avatarStorageId,
    deletingAt: p.deleted ? 0 : undefined,
    isSystem: p.isSystem === true ? true : undefined,
    visibility: { ...(p.feedLevels ?? {}), avatar: p.avatarLevel },
    // Until synced the feed flags are unknown; callers that need them check this.
    feedSynced: p.feedLevels !== undefined,
  };
}

/**
 * The public person payload (same keys as visibility.publicUserView) from a
 * profile and a presence row. Status is the presence row's own value: the
 * sweep demotes a vanished client, so no staleness window is applied here
 * (presenceApi.forUsers serves the same).
 */
export function personView(rel: Rel, profile: any, presence: any) {
  const id = profile.userId;
  const out: Record<string, unknown> = {
    _id: id,
    username: profile.username,
    name: profile.name,
  };
  if (canSeeLevel(rel, id, profile.avatarLevel, "avatar")) {
    out.avatarStorageId = profile.avatarStorageId;
  }
  if (canSeeLevel(rel, id, presence?.statusLevel, "status")) {
    out.status = presence?.status ?? "offline";
  }
  if (presence?.lastSeen != null && canSeeLevel(rel, id, presence.lastSeenLevel, "lastSeen")) {
    out.lastSeen = presence.lastSeen;
  }
  if (profile.isSystem) out.isSystem = true;
  return out;
}

/** personView for [userId], or null for a missing or deleted account. */
export async function personFor(ctx: any, rel: Rel, userId: any) {
  const [profile, presence] = await Promise.all([
    profileOrUser(ctx, userId),
    presenceOf(ctx, userId),
  ]);
  if (!profile || profile.deleted) return null;
  return personView(rel, profile, presence);
}
