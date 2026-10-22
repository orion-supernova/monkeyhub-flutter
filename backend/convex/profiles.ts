// Profile endpoints (Phase 6). Write logic is in profilesCore.ts.
//
//   versions  the subscription: [{id, u, av}] per id. Re-runs only when a
//             profile row or a friendship/guardianship it depends on changes,
//             and `av` flipping makes the client refetch just that id.
//   get       one-shot: the profile data for ids the client has no fresh
//             cache of.
//
// Neither reads `users`. The avatar level is copied on the profile row, and
// each id costs at most one profile read plus three `canSeeAs` probes.
import { v } from "convex/values";
import { query } from "./functions";
import { canSeeAs } from "./visibilityPoint";

/** Most ids one `versions` or `get` call may name. */
export const PROFILES_CAP = 100;

async function profileOf(ctx: any, id: any) {
  return await ctx.db
    .query("profiles")
    .withIndex("by_user", (q: any) => q.eq("userId", id))
    .first();
}

/** May the viewer see this profile's avatar, and is there one? */
async function avatarVisible(ctx: any, viewerId: any, row: any): Promise<boolean> {
  if (!row.avatarStorageId || row.deleted) return false;
  return await canSeeAs(ctx, viewerId, row.userId, row.avatarLevel, "avatar");
}

/**
 * `[{id, u, av}]` for each distinct id, in order. `u` is the row's
 * `updatedAt`; `av` is true when the viewer may see the avatar and one exists.
 * An id with no profile row is `{id, u: 0, av: false}`.
 */
export const versions = query({
  args: { ids: v.array(v.id("users")) },
  handler: async (ctx, { userId: viewerId, ids }) => {
    if (ids.length > PROFILES_CAP) throw new Error("TOO_MANY_IDS");
    const seen = new Set<string>();
    const out: { id: string; u: number; av: boolean }[] = [];
    for (const id of ids) {
      if (seen.has(id)) continue;
      seen.add(id);
      const row = await profileOf(ctx, id);
      out.push(
        row
          ? { id, u: row.updatedAt, av: await avatarVisible(ctx, viewerId, row) }
          : { id, u: 0, av: false },
      );
    }
    return out;
  },
});

/**
 * Profile data for each distinct id, in order; `null` for an id with no row
 * (the client falls back to the copy on the record it is rendering).
 * `avatarStorageId` is present only when the viewer may see the avatar.
 */
export const get = query({
  args: { ids: v.array(v.id("users")) },
  handler: async (ctx, { userId: viewerId, ids }) => {
    if (ids.length > PROFILES_CAP) throw new Error("TOO_MANY_IDS");
    const seen = new Set<string>();
    const out: (null | {
      id: string;
      name: string;
      username: string;
      avatarStorageId?: any;
      deleted?: boolean;
      isSystem?: boolean;
      updatedAt: number;
    })[] = [];
    for (const id of ids) {
      if (seen.has(id)) continue;
      seen.add(id);
      const row = await profileOf(ctx, id);
      if (!row) {
        out.push(null);
        continue;
      }
      const item: any = {
        id,
        name: row.name,
        username: row.username,
        updatedAt: row.updatedAt,
      };
      if (await avatarVisible(ctx, viewerId, row)) {
        item.avatarStorageId = row.avatarStorageId;
      }
      if (row.deleted) item.deleted = true;
      if (row.isSystem) item.isSystem = true;
      out.push(item);
    }
    return out;
  },
});
